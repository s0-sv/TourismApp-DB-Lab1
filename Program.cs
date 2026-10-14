using System.Data;
using Dapper;
using Npgsql;


string connStr = "Host=localhost;Port=5432;Database=tourism;Username=postgres;Password=chicha";

using (var uow = new UnitOfWork(connStr)) 
{
    Console.WriteLine("Підключення до бази успішне! Завантажую активні тури...\n");
    
    var tours = await uow.Tours.GetActiveToursAsync();
    
    foreach(var t in tours) 
    {
        Console.WriteLine($"ID: {t.Id} | Назва: {t.Title} | Категорія: {t.Category} | Ціна: {t.Price}");
    }
    
}



public class TourViewDto 
{
    public int Id { get; set; }
    public string? Title { get; set; }
    public decimal Price { get; set; }
    public string? Category { get; set; }
}

public interface ITourRepository 
{
    Task<IEnumerable<TourViewDto>> GetActiveToursAsync();
    Task SoftDeleteTourAsync(int tourId, int userId);
    Task CreateTourAsync(string title, string desc, decimal price, int guideId, int catId, int userId);
}

public class TourRepository : ITourRepository 
{
    private readonly IDbConnection _db;

    public TourRepository(IDbConnection db, IDbTransaction transaction) 
    {
        _db = db;
    }

    public async Task<IEnumerable<TourViewDto>> GetActiveToursAsync() 
    {
        return await _db.QueryAsync<TourViewDto>("SELECT * FROM v_active_tours_details");
    }

    public async Task SoftDeleteTourAsync(int tourId, int userId) 
    {
        await _db.ExecuteAsync("CALL sp_soft_delete_tour(@TourId, @UserId)", 
            new { TourId = tourId, UserId = userId });
    }

    public async Task CreateTourAsync(string title, string desc, decimal price, int guideId, int catId, int userId) 
    {
        await _db.ExecuteAsync("CALL sp_create_tour(@Title, @Desc, @Price, @GuideId, @CatId, @UserId)", 
            new { Title = title, Desc = desc, Price = price, GuideId = guideId, CatId = catId, UserId = userId });
    }
}

public class UnitOfWork : IDisposable 
{
    private readonly IDbConnection _connection;
    private IDbTransaction _transaction;
    
    public ITourRepository Tours { get; private set; }

    public UnitOfWork(string connectionString) 
    {
        _connection = new NpgsqlConnection(connectionString);
        _connection.Open();
        _transaction = _connection.BeginTransaction();
        Tours = new TourRepository(_connection, _transaction);
    }

    public void Commit() 
    {
        try 
        {
            _transaction.Commit();
        } 
        catch 
        {
            _transaction.Rollback();
            throw;
        } 
        finally 
        {
            _transaction.Dispose();
            _transaction = _connection.BeginTransaction();
        }
    }

    public void Dispose() 
    {
        _transaction?.Dispose();
        _connection?.Dispose();
    }
}