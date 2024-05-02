from app_operations import insert_user, insert_product, make_purchase, get_purchase_details
from database_setup import setup_database

if __name__ == "__main__":
    setup_database()
    user_id = insert_user("johndoe", "john@example.com")
    product_id = insert_product("Laptop", 999.99)
    make_purchase(user_id, product_id)
    purchase_info = get_purchase_details(1)
    print(f'User {purchase_info[0]} purchased {purchase_info[1]} for ${purchase_info[2]}.')