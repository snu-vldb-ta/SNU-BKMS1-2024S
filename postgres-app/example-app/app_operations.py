from database_setup import connect_to_db

def insert_user(username, email):
    conn = connect_to_db()
    cur = conn.cursor()
    cur.execute("INSERT INTO users (username, email) VALUES (%s, %s) RETURNING id;", (username, email))
    user_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return user_id

def insert_product(name, price):
    conn = connect_to_db()
    cur = conn.cursor()
    cur.execute("INSERT INTO products (name, price) VALUES (%s, %s) RETURNING id;", (name, price))
    product_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return product_id

def make_purchase(user_id, product_id):
    conn = connect_to_db()
    cur = conn.cursor()
    cur.execute("INSERT INTO purchases (user_id, product_id) VALUES (%s, %s);", (user_id, product_id))
    conn.commit()
    cur.close()
    conn.close()

def get_purchase_details(purchase_id):
    conn = connect_to_db()
    cur = conn.cursor()
    cur.execute("""
    SELECT users.username, products.name, products.price
    FROM purchases
    JOIN users ON users.id = purchases.user_id
    JOIN products ON products.id = purchases.product_id
    WHERE purchases.id = %s;
    """, (purchase_id,))
    purchase_info = cur.fetchone()
    cur.close()
    conn.close()
    return purchase_info
