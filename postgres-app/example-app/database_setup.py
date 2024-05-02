import psycopg2


def connect_to_db():
    conn_params = {
        "dbname": "postgres",
        "user": "postgres",
        "password": "postgres",
        "host": "localhost",
        "port": "5432"
    }
    return psycopg2.connect(**conn_params)


def setup_database():
    conn = connect_to_db()
    cur = conn.cursor()

    # Create tables
    cur.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) NOT NULL
    );
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        price DECIMAL NOT NULL
    );
    """)
    cur.execute("""
    CREATE TABLE IF NOT EXISTS purchases (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id),
        product_id INTEGER REFERENCES products(id),
        purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS audit (
        audit_id SERIAL PRIMARY KEY,
        table_name VARCHAR(255) NOT NULL,
        affected_id INT NOT NULL,
        operation VARCHAR(50) NOT NULL,
        log_date TIMESTAMP NOT NULL
    );
    """)

    # Creating a trigger for auditing purposes
    cur.execute("""
    CREATE OR REPLACE FUNCTION audit_log() RETURNS TRIGGER AS $$
    BEGIN
        INSERT INTO audit (table_name, affected_id, operation, log_date)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, CURRENT_TIMESTAMP);
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    cur.execute("""
    CREATE TRIGGER after_insert AFTER INSERT ON users
    FOR EACH ROW EXECUTE FUNCTION audit_log();
    """)

    conn.commit()
    cur.close()
    conn.close()
