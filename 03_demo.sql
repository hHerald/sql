-- Демонстрация: один заказ, затем изменение статуса.
-- Выполнить после 01_3nf.sql и 02_data_vault.sql. Данные откатываются.
BEGIN;

INSERT INTO shop_3nf.customer VALUES ('DEMO-C1', 'Анна Петрова', 'anna@example.com');
INSERT INTO shop_3nf.product VALUES ('DEMO-P1', 'Блокнот', 390.00);
INSERT INTO shop_3nf.sales_order
VALUES ('DEMO-O1', 'DEMO-C1', '2026-10-01 09:00+00', 'new');
INSERT INTO shop_3nf.order_item VALUES ('DEMO-O1', 'DEMO-P1', 2, 350.00);

-- Первая загрузка в Data Vault. Бизнес-ключи разрешаются в ID хабов.
INSERT INTO shop_dv.hub_customer (customer_code, load_dts, record_source)
VALUES ('DEMO-C1', '2026-10-01 09:05+00', 'shop_3nf.customer');
INSERT INTO shop_dv.hub_product (sku, load_dts, record_source)
VALUES ('DEMO-P1', '2026-10-01 09:05+00', 'shop_3nf.product');
INSERT INTO shop_dv.hub_order (order_no, load_dts, record_source)
VALUES ('DEMO-O1', '2026-10-01 09:05+00', 'shop_3nf.sales_order');

INSERT INTO shop_dv.link_order_customer (order_id, customer_id, load_dts, record_source)
SELECT ho.order_id, hc.customer_id, '2026-10-01 09:05+00', 'shop_3nf.sales_order'
FROM shop_3nf.sales_order AS o
JOIN shop_dv.hub_order AS ho USING (order_no)
JOIN shop_dv.hub_customer AS hc USING (customer_code)
WHERE o.order_no = 'DEMO-O1';

INSERT INTO shop_dv.link_order_item (order_id, product_id, load_dts, record_source)
SELECT ho.order_id, hp.product_id, '2026-10-01 09:05+00', 'shop_3nf.order_item'
FROM shop_3nf.order_item AS i
JOIN shop_dv.hub_order AS ho USING (order_no)
JOIN shop_dv.hub_product AS hp USING (sku)
WHERE i.order_no = 'DEMO-O1';

INSERT INTO shop_dv.sat_customer
SELECT h.customer_id, '2026-10-01 09:05+00', 'shop_3nf.customer', c.full_name, c.email
FROM shop_3nf.customer AS c JOIN shop_dv.hub_customer AS h USING (customer_code)
WHERE c.customer_code = 'DEMO-C1';

INSERT INTO shop_dv.sat_product
SELECT h.product_id, '2026-10-01 09:05+00', 'shop_3nf.product', p.product_name, p.catalog_price
FROM shop_3nf.product AS p JOIN shop_dv.hub_product AS h USING (sku)
WHERE p.sku = 'DEMO-P1';

INSERT INTO shop_dv.sat_order
SELECT h.order_id, '2026-10-01 09:05+00', 'shop_3nf.sales_order', o.placed_at, o.status
FROM shop_3nf.sales_order AS o JOIN shop_dv.hub_order AS h USING (order_no)
WHERE o.order_no = 'DEMO-O1';

INSERT INTO shop_dv.sat_order_item
SELECT l.order_item_id, '2026-10-01 09:05+00', 'shop_3nf.order_item', i.quantity, i.unit_price
FROM shop_3nf.order_item AS i
JOIN shop_dv.hub_order AS ho USING (order_no)
JOIN shop_dv.hub_product AS hp USING (sku)
JOIN shop_dv.link_order_item AS l ON l.order_id = ho.order_id AND l.product_id = hp.product_id
WHERE i.order_no = 'DEMO-O1';

-- В 3НФ меняется текущий статус. В Data Vault добавляется версия.
UPDATE shop_3nf.sales_order SET status = 'paid' WHERE order_no = 'DEMO-O1';

INSERT INTO shop_dv.sat_order
SELECT h.order_id, '2026-10-01 10:05+00', 'shop_3nf.sales_order', o.placed_at, o.status
FROM shop_3nf.sales_order AS o JOIN shop_dv.hub_order AS h USING (order_no)
WHERE o.order_no = 'DEMO-O1';

-- Ожидается: DEMO-O1 | paid | 700.00.
SELECT o.order_no, o.status, SUM(i.quantity * i.unit_price) AS total_rub
FROM shop_3nf.sales_order AS o JOIN shop_3nf.order_item AS i USING (order_no)
WHERE o.order_no = 'DEMO-O1'
GROUP BY o.order_no, o.status;

-- Ожидается две версии: new, затем paid.
SELECT h.order_no, s.load_dts AT TIME ZONE 'UTC' AS loaded_utc, s.status
FROM shop_dv.hub_order AS h JOIN shop_dv.sat_order AS s USING (order_id)
WHERE h.order_no = 'DEMO-O1'
ORDER BY s.load_dts;

ROLLBACK;
