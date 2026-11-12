-- PostgreSQL. Операционная модель интернет-магазина в 3НФ.
-- Выполнить один раз в пустой учебной базе данных.
BEGIN;

CREATE SCHEMA shop_3nf;

-- Покупатель определяется уникальным кодом customer_code.
CREATE TABLE shop_3nf.customer (
    customer_code text PRIMARY KEY,
    full_name text NOT NULL,
    email text NOT NULL
);

-- catalog_price — текущая цена товара в рублях.
CREATE TABLE shop_3nf.product (
    sku text PRIMARY KEY,
    product_name text NOT NULL,
    catalog_price numeric(12,2) NOT NULL CHECK (catalog_price >= 0)
);

-- У заказа ровно один покупатель. placed_at — время оформления.
CREATE TABLE shop_3nf.sales_order (
    order_no text PRIMARY KEY,
    customer_code text NOT NULL REFERENCES shop_3nf.customer (customer_code),
    placed_at timestamptz NOT NULL,
    status text NOT NULL CHECK (status IN ('new', 'paid', 'cancelled'))
);

-- Товар встречается в заказе один раз. unit_price — цена на момент продажи.
CREATE TABLE shop_3nf.order_item (
    order_no text NOT NULL REFERENCES shop_3nf.sales_order (order_no),
    sku text NOT NULL REFERENCES shop_3nf.product (sku),
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_no, sku)
);

CREATE INDEX ON shop_3nf.sales_order (customer_code);
CREATE INDEX ON shop_3nf.order_item (sku);

COMMIT;
