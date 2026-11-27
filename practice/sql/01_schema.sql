\set ON_ERROR_STOP on
BEGIN;
CREATE SCHEMA inventory;
REVOKE ALL ON SCHEMA inventory FROM PUBLIC;
CREATE TABLE inventory.categories (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 name varchar(100) NOT NULL UNIQUE CHECK (btrim(name) <> '')
);
CREATE TABLE inventory.products (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 name varchar(200) NOT NULL CHECK (btrim(name) <> ''),
 category_id integer NOT NULL REFERENCES inventory.categories(id),
 stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
 purchase_price numeric(12,2) NOT NULL CHECK (purchase_price >= 0),
 selling_price numeric(12,2) NOT NULL CHECK (selling_price >= 0)
);
CREATE UNIQUE INDEX products_name_unique ON inventory.products(lower(btrim(name)));
CREATE TABLE inventory.movements (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 product_id integer NOT NULL REFERENCES inventory.products(id),
 kind varchar(10) NOT NULL CHECK (kind IN ('opening','receipt','sale')),
 quantity integer NOT NULL CHECK (quantity > 0),
 purchase_price numeric(12,2) NOT NULL CHECK (purchase_price >= 0),
 selling_price numeric(12,2) NOT NULL CHECK (selling_price >= 0),
 occurred_at timestamptz NOT NULL DEFAULT current_timestamp,
 actor text NOT NULL DEFAULT session_user
);
CREATE INDEX movements_product_date ON inventory.movements(product_id,occurred_at);
CREATE VIEW inventory.catalog AS
 SELECT p.id,p.name,c.name AS category,p.stock,p.purchase_price,p.selling_price
 FROM inventory.products p JOIN inventory.categories c ON c.id=p.category_id;
CREATE VIEW inventory.sales_report AS
 SELECT m.id,p.name,m.quantity,m.occurred_at,m.actor,
 m.selling_price*m.quantity AS revenue,
 (m.selling_price-m.purchase_price)*m.quantity AS margin
 FROM inventory.movements m JOIN inventory.products p ON p.id=m.product_id WHERE m.kind='sale';
CREATE FUNCTION inventory.receive_product(p_name text,p_category text,p_quantity integer,p_purchase numeric,p_selling numeric)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, inventory AS $$
DECLARE v_category integer; v_product integer;
BEGIN
 IF p_name IS NULL OR btrim(p_name)='' OR length(btrim(p_name))>200 OR p_quantity IS NULL OR p_quantity<=0
 OR p_purchase IS NULL OR p_purchase<0 OR p_selling IS NULL OR p_selling<0 THEN
  RAISE EXCEPTION 'Invalid receipt values';
 END IF;
 SELECT id INTO v_category FROM inventory.categories WHERE name=p_category;
 IF v_category IS NULL THEN RAISE EXCEPTION 'Unknown category'; END IF;
 INSERT INTO inventory.products(name,category_id,stock,purchase_price,selling_price)
 VALUES(btrim(p_name),v_category,p_quantity,p_purchase,p_selling)
 ON CONFLICT (lower(btrim(name))) DO UPDATE SET
 purchase_price=round((products.purchase_price*products.stock+EXCLUDED.purchase_price*EXCLUDED.stock)/(products.stock::numeric+EXCLUDED.stock),2),
 stock=products.stock+EXCLUDED.stock, selling_price=EXCLUDED.selling_price
 WHERE products.category_id=EXCLUDED.category_id
 RETURNING id INTO v_product;
 IF v_product IS NULL THEN RAISE EXCEPTION 'Product category differs'; END IF;
 INSERT INTO inventory.movements(product_id,kind,quantity,purchase_price,selling_price)
 VALUES(v_product,'receipt',p_quantity,p_purchase,p_selling);
 RETURN v_product;
END $$;
CREATE FUNCTION inventory.sell_product(p_id integer,p_quantity integer)
RETURNS TABLE(revenue numeric,margin numeric) LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, inventory AS $$
DECLARE v_product inventory.products%ROWTYPE;
BEGIN
 IF p_quantity IS NULL OR p_quantity<=0 THEN RAISE EXCEPTION 'Quantity must be positive'; END IF;
 UPDATE inventory.products SET stock=stock-p_quantity WHERE id=p_id AND stock>=p_quantity RETURNING * INTO v_product;
 IF NOT FOUND THEN RAISE EXCEPTION 'Product missing or insufficient stock'; END IF;
 INSERT INTO inventory.movements(product_id,kind,quantity,purchase_price,selling_price)
 VALUES(p_id,'sale',p_quantity,v_product.purchase_price,v_product.selling_price);
 RETURN QUERY SELECT v_product.selling_price*p_quantity,(v_product.selling_price-v_product.purchase_price)*p_quantity;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA inventory FROM PUBLIC;
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='prodahi_operator') THEN CREATE ROLE prodahi_operator NOLOGIN; END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='prodahi_reader') THEN CREATE ROLE prodahi_reader NOLOGIN; END IF;
END $$;
GRANT USAGE ON SCHEMA inventory TO prodahi_operator,prodahi_reader;
GRANT SELECT ON inventory.catalog,inventory.categories,inventory.sales_report TO prodahi_operator,prodahi_reader;
GRANT EXECUTE ON FUNCTION inventory.receive_product(text,text,integer,numeric,numeric),inventory.sell_product(integer,integer) TO prodahi_operator;
COMMIT;
