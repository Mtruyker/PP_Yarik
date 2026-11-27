using System;
using System.Collections.Generic;
using System.IO;
using Npgsql;

namespace Prodahi_Ychet2
{
    public sealed class ProductRepository
    {
        // Local credentials are kept outside the source tree.
        private NpgsqlConnection Open()
        {
            var path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Prodahi_Ychet2", "connection.txt");
            if (!File.Exists(path)) throw new InvalidOperationException("Не настроено подключение. Создайте файл " + path);
            var connection = new NpgsqlConnection(File.ReadAllText(path).Trim());
            try { connection.Open(); return connection; }
            catch { connection.Dispose(); throw; }
        }

        public List<Product> LoadProducts()
        {
            var products = new List<Product>();
            using (var connection = Open())
            using (var command = new NpgsqlCommand("SELECT id,name,category,stock,purchase_price,selling_price FROM inventory.catalog ORDER BY id", connection))
            using (var reader = command.ExecuteReader())
                while (reader.Read()) products.Add(new Product { Id = reader.GetInt32(0), Name = reader.GetString(1), Category = reader.GetString(2), Stock = reader.GetInt32(3), PurchasePrice = reader.GetDecimal(4), SellingPrice = reader.GetDecimal(5) });
            return products;
        }

        public List<string> LoadCategories()
        {
            var categories = new List<string>();
            using (var connection = Open())
            using (var command = new NpgsqlCommand("SELECT name FROM inventory.categories ORDER BY id", connection))
            using (var reader = command.ExecuteReader())
                while (reader.Read()) categories.Add(reader.GetString(0));
            return categories;
        }

        public void Receive(string name, string category, int quantity, decimal purchase, decimal selling)
        {
            using (var connection = Open())
            using (var command = new NpgsqlCommand("SELECT inventory.receive_product(@name,@category,@quantity,@purchase,@selling)", connection))
            {
                command.Parameters.AddWithValue("name", name);
                command.Parameters.AddWithValue("category", category);
                command.Parameters.AddWithValue("quantity", quantity);
                command.Parameters.AddWithValue("purchase", purchase);
                command.Parameters.AddWithValue("selling", selling);
                command.ExecuteScalar();
            }
        }

        public decimal[] Sell(int productId, int quantity)
        {
            using (var connection = Open())
            using (var command = new NpgsqlCommand("SELECT revenue,margin FROM inventory.sell_product(@id,@quantity)", connection))
            {
                command.Parameters.AddWithValue("id", productId);
                command.Parameters.AddWithValue("quantity", quantity);
                using (var reader = command.ExecuteReader())
                {
                    if (!reader.Read()) throw new InvalidOperationException("Сервер не вернул результат продажи.");
                    return new[] { reader.GetDecimal(0), reader.GetDecimal(1) };
                }
            }
        }
    }
}
