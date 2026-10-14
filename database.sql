CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

-- користувачі
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role_id INT REFERENCES roles(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- профілі туристів
CREATE TABLE tourists (
    id SERIAL PRIMARY KEY,
    user_id INT UNIQUE NOT NULL REFERENCES users(id),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20)
);

-- профілі гідів
CREATE TABLE guides (
    id SERIAL PRIMARY KEY,
    user_id INT UNIQUE NOT NULL REFERENCES users(id),
    bio TEXT,
    rating DECIMAL(3,2) DEFAULT 0
);

-- довідник категорій турів
CREATE TABLE tour_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- тури
CREATE TABLE tours (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    guide_id INT REFERENCES guides(id),
    category_id INT REFERENCES tour_categories(id),
    is_deleted BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by INT REFERENCES users(id)
);

-- локації
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    country VARCHAR(100) NOT NULL,
    city VARCHAR(100)
);

-- маршрут
CREATE TABLE tour_locations (
    id SERIAL PRIMARY KEY,
    tour_id INT REFERENCES tours(id),
    location_id INT REFERENCES locations(id),
    visit_order INT NOT NULL
);

-- бронювання
CREATE TABLE bookings (
    id SERIAL PRIMARY KEY,
    tour_id INT REFERENCES tours(id),
    tourist_id INT REFERENCES tourists(id),
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'Pending',
    is_deleted BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by INT REFERENCES users(id)
);

-- платежі за бронювання
CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    booking_id INT UNIQUE NOT NULL REFERENCES bookings(id),
    amount DECIMAL(10, 2) NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'Completed'
);

-- відгуки користувачів
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    tour_id INT REFERENCES tours(id),
    tourist_id INT REFERENCES tourists(id),
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- готелі
CREATE TABLE hotels (
    id SERIAL PRIMARY KEY,
    location_id INT REFERENCES locations(id),
    name VARCHAR(255) NOT NULL,
    star_rating INT CHECK (star_rating >= 1 AND star_rating <= 5)
);

-- готелі, що використовуються в турі
CREATE TABLE tour_hotels (
    id SERIAL PRIMARY KEY,
    tour_id INT REFERENCES tours(id),
    hotel_id INT REFERENCES hotels(id),
    nights_count INT NOT NULL
);

-- довідник типів транспорту
CREATE TABLE transport_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- транспорт у конкретному турі
CREATE TABLE tour_transports (
    id SERIAL PRIMARY KEY,
    tour_id INT REFERENCES tours(id),
    transport_type_id INT REFERENCES transport_types(id)
);




-- Простий індекс для швидкого пошуку по зовнішньому ключу
CREATE INDEX idx_tours_category ON tours(category_id);

-- Складений індекс для пришвидшення пошуку відгуків
CREATE INDEX idx_reviews_tour_tourist ON reviews(tour_id, tourist_id);

-- Частковий (фільтрований) індекс для активних турів
CREATE INDEX idx_active_tours ON tours(id) WHERE is_deleted = FALSE;




CREATE OR REPLACE FUNCTION fn_update_timestamp() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_tours_update BEFORE UPDATE ON tours
FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();


CREATE TRIGGER trg_bookings_update BEFORE UPDATE ON bookings
FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();


CREATE OR REPLACE VIEW v_active_tours_details AS
SELECT t.id, t.title, t.price, c.name AS category, g.bio AS guide_info
FROM tours t
JOIN tour_categories c ON t.category_id = c.id
JOIN guides g ON t.guide_id = g.id
WHERE t.is_deleted = FALSE;


CREATE OR REPLACE VIEW v_active_bookings AS
SELECT b.id, t.title AS tour_title, tr.first_name || ' ' || tr.last_name AS tourist_name, b.status
FROM bookings b
JOIN tours t ON b.tour_id = t.id
JOIN tourists tr ON b.tourist_id = tr.id
WHERE b.is_deleted = FALSE;


CREATE OR REPLACE PROCEDURE sp_soft_delete_tour(p_tour_id INT, p_user_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE tours SET is_deleted = TRUE, updated_by = p_user_id WHERE id = p_tour_id;
END;
$$;


CREATE OR REPLACE PROCEDURE sp_soft_delete_booking(p_booking_id INT, p_user_id INT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE bookings SET is_deleted = TRUE, updated_by = p_user_id WHERE id = p_booking_id;
END;
$$;


CREATE OR REPLACE PROCEDURE sp_create_tour(
    p_title VARCHAR, p_description TEXT, p_price DECIMAL, p_guide_id INT, p_category_id INT, p_user_id INT
) LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tours (title, description, price, guide_id, category_id, updated_by)
    VALUES (p_title, p_description, p_price, p_guide_id, p_category_id, p_user_id);
END;
$$;


CREATE OR REPLACE FUNCTION fn_get_tour_avg_rating(p_tour_id INT) RETURNS DECIMAL AS $$
DECLARE avg_rating DECIMAL;
BEGIN
    SELECT COALESCE(AVG(rating), 0) INTO avg_rating FROM reviews WHERE tour_id = p_tour_id;
    RETURN avg_rating;
END;
$$ LANGUAGE plpgsql;


-- ТЕСТОВІ ДАНІ:

INSERT INTO roles (name) VALUES ('admin'), ('tourist'), ('guide') ON CONFLICT DO NOTHING;

INSERT INTO users (username, email, password_hash, role_id) VALUES 
('olena_admin', 'olena@admin.com', 'hash123', 1),
('max_tourist', 'max@mail.com', 'hash123', 2),
('anna_guide', 'anna@guide.com', 'hash123', 3),
('igor_tourist', 'igor@mail.com', 'hash123', 2);


INSERT INTO tourists (user_id, first_name, last_name, phone) VALUES 
(2, 'Максим', 'Коваленко', '+380501234567'),
(4, 'Ігор', 'Шевченко', '+380671234567');


INSERT INTO guides (user_id, bio, rating) VALUES 
(3, 'Експерт з історичних турів Європою.', 4.8);


INSERT INTO tour_categories (name) VALUES 
('Екскурсійний'), 
('Екстрим'), 
('Гірський туризм'),
('Пляжний відпочинок') ON CONFLICT DO NOTHING;


INSERT INTO locations (name, country, city) VALUES 
('Ейфелева вежа', 'Франція', 'Париж'),
('Колізей', 'Італія', 'Рим'),
('Буковель', 'Україна', 'Поляниця');


INSERT INTO tours (title, description, price, guide_id, category_id, updated_by) VALUES 
('Похід на Говерлу', 'Цікавий гірський маршрут', 1500.00, 1, 3, 1),
('Романтичний Париж', 'Три дні у столиці кохання.', 25000.00, 1, 1, 1),
('Історичний Рим', 'Занурення в античну історію.', 18000.00, 1, 1, 1),
('Лижний тур в Карпати', 'Тиждень екстриму.', 12000.00, 1, 2, 1);


INSERT INTO tour_locations (tour_id, location_id, visit_order) VALUES 
(2, 1, 1),
(3, 2, 1),
(4, 3, 1);


INSERT INTO bookings (tour_id, tourist_id, status, updated_by) VALUES 
(2, 1, 'Confirmed', 1),
(3, 2, 'Pending', 1);

INSERT INTO payments (booking_id, amount, status) VALUES 
(1, 25000.00, 'Completed');


INSERT INTO reviews (tour_id, tourist_id, rating, comment) VALUES 
(2, 1, 5, 'Чудовий тур! Париж прекрасний.');