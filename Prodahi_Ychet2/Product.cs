using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace Prodahi_Ychet2
{
    public class Product : INotifyPropertyChanged
    {
        public int Id { get; set; }
        private string _name;
        private string _category;
        private int _stock;
        private decimal _purchasePrice;
        private decimal _sellingPrice;

        public string Name { get => _name; set { _name = value; OnPropertyChanged(); } }
        public string Category { get => _category; set { _category = value; OnPropertyChanged(); } }
        public int Stock { get => _stock; set { _stock = value; OnPropertyChanged(); } }
        public decimal PurchasePrice { get => _purchasePrice; set { _purchasePrice = value; OnPropertyChanged(); } }
        public decimal SellingPrice { get => _sellingPrice; set { _sellingPrice = value; OnPropertyChanged(); } }

        public event PropertyChangedEventHandler PropertyChanged;
        protected void OnPropertyChanged([CallerMemberName] string name = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
