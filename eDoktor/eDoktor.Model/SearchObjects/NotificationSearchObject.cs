namespace eDoktor.Model.SearchObjects
{
    public class NotificationSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }
        public bool? IsRead { get; set; }
    }
}
