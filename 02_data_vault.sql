-- PostgreSQL. Data Vault интернет-магазина.
-- Выполнить один раз в пустой учебной базе данных или после 01_3nf.sql.
-- load_dts — время загрузки. record_source — имя источника.
BEGIN;

CREATE SCHEMA shop_dv;

-- Хабы: одна строка на уникальный бизнес-ключ.
-- Суррогатные ключи генерирует PostgreSQL.
CREATE TABLE shop_dv.hub_customer (
    customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_code text NOT NULL UNIQUE,
    load_dts timestamptz NOT NULL,
    record_source text NOT NULL
);

CREATE TABLE shop_dv.hub_product (
    product_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku text NOT NULL UNIQUE,
    load_dts timestamptz NOT NULL,
    record_source text NOT NULL
);

CREATE TABLE shop_dv.hub_order (
    order_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_no text NOT NULL UNIQUE,
    load_dts timestamptz NOT NULL,
    record_source text NOT NULL
);

-- Связи: одна строка на уникальную комбинацию ключей хабов.
CREATE TABLE shop_dv.link_order_customer (
    order_customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id bigint NOT NULL REFERENCES shop_dv.hub_order (order_id),
    customer_id bigint NOT NULL REFERENCES shop_dv.hub_customer (customer_id),
    load_dts timestamptz NOT NULL,
    record_source text NOT NULL,
    UNIQUE (order_id, customer_id)
);

CREATE TABLE shop_dv.link_order_item (
    order_item_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id bigint NOT NULL REFERENCES shop_dv.hub_order (order_id),
    product_id bigint NOT NULL REFERENCES shop_dv.hub_product (product_id),
    load_dts timestamptz NOT NULL,
    record_source text NOT NULL,
    UNIQUE (order_id, product_id)
);

-- Спутники: одна версия атрибутов на родительский ключ и время загрузки.
-- Изменения записываются добавлением новой строки. Время загрузки каждой
-- версии одного родителя должно быть уникальным.
CREATE TABLE shop_dv.sat_customer (
    customer_id bigint NOT NULL REFERENCES shop_dv.hub_customer (customer_id),
    load_dts timestamptz NOT NULL,
    record_source text NOT NULL,
    full_name text NOT NULL,
    email text NOT NULL,
    PRIMARY KEY (customer_id, load_dts)
);

CREATE TABLE shop_dv.sat_product (
    product_id bigint NOT NULL REFERENCES shop_dv.hub_product (product_id),
    load_dts timestamptz NOT NULL,
    record_source text NOT NULL,
    product_name text NOT NULL,
    catalog_price numeric(12,2) NOT NULL CHECK (catalog_price >= 0),
    PRIMARY KEY (product_id, load_dts)
);

CREATE TABLE shop_dv.sat_order (
    order_id bigint NOT NULL REFERENCES shop_dv.hub_order (order_id),
    load_dts timestamptz NOT NULL,
    record_source text NOT NULL,
    placed_at timestamptz NOT NULL,
    status text NOT NULL CHECK (status IN ('new', 'paid', 'cancelled')),
    PRIMARY KEY (order_id, load_dts)
);

CREATE TABLE shop_dv.sat_order_item (
    order_item_id bigint NOT NULL REFERENCES shop_dv.link_order_item (order_item_id),
    load_dts timestamptz NOT NULL,
    record_source text NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_item_id, load_dts)
);

COMMIT;
