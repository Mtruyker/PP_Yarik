using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Input;
using Npgsql;

namespace Prodahi_Ychet2
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private readonly ProductRepository repository = new ProductRepository();
        public ObservableCollection<Product> Products { get; } = new ObservableCollection<Product>();
        public ObservableCollection<string> Categories { get; } = new ObservableCollection<string>();
        public string NewName { get; set; }
        public string NewCategory { get; set; }
        // Keep raw input so invalid text cannot silently reuse the previous numeric value.
        public string NewStock { get; set; } = "1";
        public string NewPurchasePrice { get; set; } = "0";
        public string NewSellingPrice { get; set; } = "0";
        public string SaleQuantity { get; set; } = "1";
        private Product selectedProduct;
        public Product SelectedProduct { get => selectedProduct; set { selectedProduct = value; OnPropertyChanged(); } }
        private string status;
        public string Status { get => status; private set { status = value; OnPropertyChanged(); } }
        public ICommand AddProductCommand { get; }
        public ICommand SellProductCommand { get; }
        public ICommand RefreshCommand { get; }

        public MainViewModel()
        {
            AddProductCommand = new RelayCommand(_ => ExecuteAddProduct());
            SellProductCommand = new RelayCommand(_ => ExecuteSellProduct());
            RefreshCommand = new RelayCommand(_ => Refresh());
            Refresh();
        }
        private bool Refresh()
        {
            try
            {
                var categories = repository.LoadCategories();
                var products = repository.LoadProducts();
                var id = SelectedProduct?.Id;
                Categories.Clear(); foreach (var c in categories) Categories.Add(c);
                if (!Categories.Contains(NewCategory)) NewCategory = Categories.FirstOrDefault();
                OnPropertyChanged(nameof(NewCategory));
                Products.Clear(); foreach (var p in products) Products.Add(p);
                SelectedProduct = Products.FirstOrDefault(p => p.Id == id);
                Status = "PostgreSQL • товаров: " + Products.Count;
                return true;
            }
            catch (Exception ex) { Status = ErrorText(ex); return false; }
        }
        private static string ErrorText(Exception ex)
        {
            if (ex is PostgresException pg)
            {
                if (pg.MessageText == "Product missing or insufficient stock") return "Недостаточно товара на складе. Обновите каталог.";
                if (pg.MessageText == "Product category differs") return "Товар с таким названием относится к другой категории.";
                if (pg.SqlState == "42501") return "Недостаточно прав для операции.";
                return "База данных отклонила операцию. Проверьте значения и ограничения полей.";
            }
            if (ex is InvalidOperationException) return ex.Message;
            return "Нет связи с PostgreSQL. Проверьте сервер и настройки подключения.";
        }
        private static bool ReadPrice(string text, out decimal value)
        {
            return decimal.TryParse(text?.Trim().Replace('.', ','), NumberStyles.AllowDecimalPoint | NumberStyles.AllowLeadingSign, CultureInfo.GetCultureInfo("ru-RU"), out value)
                && value >= 0 && value <= 9999999999.99m && decimal.Round(value, 2) == value;
        }
        private void ExecuteAddProduct()
        {
            int quantity; decimal purchase, selling;
            if (string.IsNullOrWhiteSpace(NewName) || NewName.Trim().Length > 200 || !Categories.Contains(NewCategory))
            { MessageBox.Show("Введите название до 200 символов и выберите категорию."); return; }
            if (!int.TryParse(NewStock, out quantity) || quantity <= 0 || !ReadPrice(NewPurchasePrice, out purchase) || !ReadPrice(NewSellingPrice, out selling))
            { MessageBox.Show("Количество должно быть целым и больше нуля. Цены — неотрицательными, не более 9 999 999 999,99 руб., с точностью до копейки."); return; }
            try { repository.Receive(NewName.Trim(), NewCategory, quantity, purchase, selling); }
            catch (Exception ex) { MessageBox.Show(ErrorText(ex)); return; }
            NewName = ""; NewStock = "1"; NewPurchasePrice = "0"; NewSellingPrice = "0";
            OnPropertyChanged(nameof(NewName)); OnPropertyChanged(nameof(NewStock));
            OnPropertyChanged(nameof(NewPurchasePrice)); OnPropertyChanged(nameof(NewSellingPrice));
            var refreshed = Refresh();
            MessageBox.Show("Поступление сохранено." + (refreshed ? "" : " Каталог не обновился; нажмите «Обновить»."));
        }
        private void ExecuteSellProduct()
        {
            int quantity;
            if (SelectedProduct == null) { MessageBox.Show("Выберите товар в таблице."); return; }
            if (!int.TryParse(SaleQuantity, out quantity) || quantity <= 0) { MessageBox.Show("Количество должно быть целым и больше нуля."); return; }
            decimal[] result;
            try { result = repository.Sell(SelectedProduct.Id, quantity); }
            catch (Exception ex) { MessageBox.Show(ErrorText(ex)); return; }
            var refreshed = Refresh();
            MessageBox.Show($"Продано на сумму: {result[0]:N2} руб.\nВаловая прибыль: {result[1]:N2} руб." + (refreshed ? "" : "\nКаталог не обновился; нажмите «Обновить»."), "Продажа сохранена");
        }
        public event PropertyChangedEventHandler PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string name = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
    public class RelayCommand : ICommand
    {
        private readonly Action<object> execute;
        public RelayCommand(Action<object> execute) { this.execute = execute; }
        public bool CanExecute(object parameter) => true;
        public void Execute(object parameter) => execute(parameter);
        public event EventHandler CanExecuteChanged { add { } remove { } }
    }
}
