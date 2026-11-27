\set ON_ERROR_STOP on
BEGIN;
SET LOCAL ROLE prodahi_app;
DO $$
DECLARE p integer; n integer; amount numeric; profit numeric;
BEGIN
 p:=inventory.receive_product('__practice_test__','Процессоры',10,100,150);
 PERFORM inventory.receive_product('__practice_test__','Процессоры',10,200,300);
 SELECT stock INTO n FROM inventory.catalog WHERE id=p;
 IF n<>20 THEN RAISE EXCEPTION 'Receipt failed'; END IF;
 SELECT revenue,margin INTO amount,profit FROM inventory.sell_product(p,2);
 IF amount<>600 OR profit<>300 THEN RAISE EXCEPTION 'Sale totals failed'; END IF;
 SELECT stock INTO n FROM inventory.catalog WHERE id=p;
 IF n<>18 THEN RAISE EXCEPTION 'Sale stock failed'; END IF;
 BEGIN PERFORM inventory.sell_product(p,-1); RAISE EXCEPTION 'Negative quantity accepted' USING ERRCODE='XX000';
 EXCEPTION WHEN raise_exception THEN NULL; END;
 BEGIN PERFORM inventory.sell_product(p,1000); RAISE EXCEPTION 'Oversell accepted' USING ERRCODE='XX000';
 EXCEPTION WHEN raise_exception THEN NULL; END;
 BEGIN PERFORM inventory.receive_product('bad','Процессоры',0,1,1); RAISE EXCEPTION 'Zero accepted' USING ERRCODE='XX000';
 EXCEPTION WHEN raise_exception THEN NULL; END;
 BEGIN PERFORM inventory.receive_product('bad','Процессоры',1,-1,1); RAISE EXCEPTION 'Negative price accepted' USING ERRCODE='XX000';
 EXCEPTION WHEN raise_exception THEN NULL; END;
 BEGIN UPDATE inventory.products SET stock=0 WHERE id=p; RAISE EXCEPTION 'Direct update allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN DELETE FROM inventory.movements; RAISE EXCEPTION 'Journal deletion allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 SELECT stock INTO n FROM inventory.catalog WHERE id=p;
 IF n<>18 THEN RAISE EXCEPTION 'Rejected operation changed stock'; END IF;
 RAISE NOTICE 'PASS: receipts, weighted cost, sale, invalid inputs, oversell, protected tables';
END $$;
RESET ROLE;
DO $$ BEGIN
 IF (SELECT count(*) FROM inventory.movements m JOIN inventory.products p ON p.id=m.product_id WHERE p.name='__practice_test__')<>3
 THEN RAISE EXCEPTION 'Journal failed'; END IF;
 RAISE NOTICE 'PASS: movement journal';
END $$;
ROLLBACK;
SELECT count(*) AS products, sum(stock) AS units FROM inventory.products;
