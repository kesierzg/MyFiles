-- ============================================================
-- BUTANSKI BAZAR CIENI
-- ============================================================
-- [1] OLTP  - schemat zrodlowy
-- [2] OLTP  - dane testowe
-- [3] DWH   - schemat gwiazdy (wymiary + fakty)
-- [4] ETL   - zasilanie hurtowni (MERGE + SCD)
-- [5] ANALITYKA - agregacje, ROLLUP/CUBE, funkcje okna
-- [6] OPTYMALIZACJA - indeksy, partycjonowanie
-- ============================================================

-- ============================================================
-- [0] CZYSZCZENIE - DROP jezeli tabele juz istnieja
-- ============================================================
BEGIN EXECUTE IMMEDIATE 'DROP TABLE factSales CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE factSales_partitioned CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE dimCustomer CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE dimProduct CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE dimStore CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE dimPaymentMethod CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE dimDate CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE oltp_payments CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE oltp_order_items CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE oltp_orders CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE oltp_stores CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE oltp_customers CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE oltp_products CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE oltp_categories CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/


-- ============================================================
-- [1] OLTP - SCHEMAT ZRODLOWY
-- ============================================================

CREATE TABLE oltp_categories (
    category_id  NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         VARCHAR2(100) NOT NULL,
    parent_id    NUMBER        REFERENCES oltp_categories(category_id),
    danger_level NUMBER(1)     DEFAULT 1 CONSTRAINT chk_danger CHECK (danger_level BETWEEN 1 AND 5)
);

CREATE TABLE oltp_products (
    product_id      NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR2(150) NOT NULL,
    category_id     NUMBER        NOT NULL REFERENCES oltp_categories(category_id),
    unit_price      NUMBER(14,2)  NOT NULL CONSTRAINT chk_price CHECK (unit_price >= 0),
    unit_cost       NUMBER(14,2)  NOT NULL CONSTRAINT chk_cost  CHECK (unit_cost  >= 0),
    currency        VARCHAR2(10)  DEFAULT 'SMOCZE'
        CONSTRAINT chk_curr CHECK (currency IN ('SMOCZE','GOLD','KARMA','USD','TALARY')),
    is_cursed       NUMBER(1)     DEFAULT 0 CONSTRAINT chk_curs  CHECK (is_cursed  IN (0,1)),
    is_active       NUMBER(1)     DEFAULT 1 CONSTRAINT chk_activ CHECK (is_active   IN (0,1)),
    origin_realm    VARCHAR2(50),
    requires_ritual NUMBER(1)     DEFAULT 0 CONSTRAINT chk_ritu  CHECK (requires_ritual IN (0,1))
);

CREATE TABLE oltp_customers (
    customer_id  NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name   VARCHAR2(50)  NOT NULL,
    last_name    VARCHAR2(50)  NOT NULL,
    email        VARCHAR2(100) NOT NULL UNIQUE,
    birth_date   DATE,
    city         VARCHAR2(50),
    region       VARCHAR2(50),
    country      VARCHAR2(50)  DEFAULT 'Polska',
    soul_status  VARCHAR2(20)  DEFAULT 'intact'
        CONSTRAINT chk_soul CHECK (soul_status IN ('intact','partially_sold','sold','disputed','on_layaway')),
    loyalty_tier VARCHAR2(30)  DEFAULT 'cursed_newcomer'
        CONSTRAINT chk_loy CHECK (loyalty_tier IN ('cursed_newcomer','regular_damned','silver_sinner','gold_apostate','platinum_heretic')),
    how_found_us VARCHAR2(50)  DEFAULT 'forbidden_grimoire',
    is_banned    NUMBER(1)     DEFAULT 0 CONSTRAINT chk_ban CHECK (is_banned IN (0,1))
);

CREATE TABLE oltp_stores (
    store_id        NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR2(100) NOT NULL,
    dimension       VARCHAR2(80)  NOT NULL,
    access_method   VARCHAR2(80),
    store_type      VARCHAR2(30)  DEFAULT 'interdimensional'
        CONSTRAINT chk_stype CHECK (store_type IN ('interdimensional','dreamscape','void_kiosk','pocket_universe','cursed_popup')),
    danger_rating   NUMBER(1)     DEFAULT 2 CONSTRAINT chk_sdang CHECK (danger_rating BETWEEN 1 AND 5),
    manager_name    VARCHAR2(100),
    manager_species VARCHAR2(50)  DEFAULT 'Unknown Entity',
    is_open         NUMBER(1)     DEFAULT 1 CONSTRAINT chk_open CHECK (is_open IN (0,1))
);

CREATE TABLE oltp_orders (
    order_id    NUMBER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id NUMBER       NOT NULL REFERENCES oltp_customers(customer_id),
    store_id    NUMBER       NOT NULL REFERENCES oltp_stores(store_id),
    order_date  DATE         NOT NULL,
    status      VARCHAR2(20) DEFAULT 'completed'
        CONSTRAINT chk_ost CHECK (status IN ('pending','completed','cancelled','returned','cursed_pending'))
);

CREATE TABLE oltp_order_items (
    item_id       NUMBER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id      NUMBER       NOT NULL REFERENCES oltp_orders(order_id),
    product_id    NUMBER       NOT NULL REFERENCES oltp_products(product_id),
    quantity      NUMBER       NOT NULL CONSTRAINT chk_qty CHECK (quantity > 0),
    unit_price    NUMBER(14,2) NOT NULL CONSTRAINT chk_up  CHECK (unit_price >= 0),
    discount_pct  NUMBER(5,2)  DEFAULT 0 CONSTRAINT chk_dsc CHECK (discount_pct BETWEEN 0 AND 100),
    soul_fraction NUMBER(5,4)  DEFAULT 0   -- ulamek duszy oddany jako doplata
);

CREATE TABLE oltp_payments (
    payment_id   NUMBER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id     NUMBER       NOT NULL REFERENCES oltp_orders(order_id),
    payment_date DATE         NOT NULL,
    amount       NUMBER(14,2) NOT NULL,
    currency     VARCHAR2(10) DEFAULT 'SMOCZE'
        CONSTRAINT chk_pcurr CHECK (currency IN ('SMOCZE','GOLD','KARMA','USD','TALARY')),
    method       VARCHAR2(30) DEFAULT 'soul_transfer'
        CONSTRAINT chk_meth CHECK (method IN ('soul_transfer','golden_coins','karma_points','blood_oath','blik','dark_card','wish_token'))
);

CREATE INDEX idx_oi_order   ON oltp_order_items(order_id);
CREATE INDEX idx_oi_product ON oltp_order_items(product_id);
CREATE INDEX idx_ord_cust   ON oltp_orders(customer_id);
CREATE INDEX idx_ord_store  ON oltp_orders(store_id);
CREATE INDEX idx_ord_date   ON oltp_orders(order_date);
CREATE INDEX idx_pay_order  ON oltp_payments(order_id);


-- ============================================================
-- [2] OLTP - DANE TESTOWE
-- ============================================================

INSERT INTO oltp_categories (name, parent_id, danger_level) VALUES ('Dusze',               NULL, 4);
INSERT INTO oltp_categories (name, parent_id, danger_level) VALUES ('Eliksiry',            NULL, 3);
INSERT INTO oltp_categories (name, parent_id, danger_level) VALUES ('Relikwie',            NULL, 3);
INSERT INTO oltp_categories (name, parent_id, danger_level) VALUES ('Klatwy',              NULL, 4);
INSERT INTO oltp_categories (name, parent_id, danger_level) VALUES ('Artefakty Kosmiczne', NULL, 5);
INSERT INTO oltp_categories (name, parent_id, danger_level) VALUES ('Dusze Ludzkie',       1,    4);
INSERT INTO oltp_categories (name, parent_id, danger_level) VALUES ('Eliksiry Niesmiertelnosci', 2, 5);
INSERT INTO oltp_categories (name, parent_id, danger_level) VALUES ('Klatwy Rodzinne',     4,    4);

INSERT INTO oltp_products (name, category_id, unit_price, unit_cost, currency, is_cursed, origin_realm, requires_ritual) VALUES
    ('Dusza Kat. A (Premium)',                     6,  9999.99,  1000.00, 'SMOCZE', 0, 'Swiat Zywych', 0);
INSERT INTO oltp_products (name, category_id, unit_price, unit_cost, currency, is_cursed, origin_realm, requires_ritual) VALUES
    ('Eliksir Niesmiertelnosci (oryginalny)',       7, 99999.99, 50000.00, 'GOLD',   1, 'Olimp',        1);
INSERT INTO oltp_products (name, category_id, unit_price, unit_cost, currency, is_cursed, origin_realm, requires_ritual) VALUES
    ('Eliksir Niesmiertelnosci (podrobka)',         7,  1299.99,    15.00, 'USD',    1, 'Shangri-La',   0);
INSERT INTO oltp_products (name, category_id, unit_price, unit_cost, currency, is_cursed, origin_realm, requires_ritual) VALUES
    ('Arka Przymierza (nie dotykac)',               3, 250000.00,   0.00, 'TALARY', 1, 'Nieznany',     1);
INSERT INTO oltp_products (name, category_id, unit_price, unit_cost, currency, is_cursed, origin_realm, requires_ritual) VALUES
    ('Klatwa Rodzinna Premium (7 pokolen)',         8,   1999.00, 150.00, 'KARMA',  1, 'Otchlan',      1);
INSERT INTO oltp_products (name, category_id, unit_price, unit_cost, currency, is_cursed, origin_realm, requires_ritual) VALUES
    ('Kamien Filozoficzny',                         5, 500000.00,   0.00, 'TALARY', 1, 'Nieznany',     1);
INSERT INTO oltp_products (name, category_id, unit_price, unit_cost, currency, is_cursed, origin_realm, requires_ritual) VALUES
    ('iPhone 9',                                    5,  19999.99, 18000.00, 'USD',  0, 'Cupertino',    0);

INSERT INTO oltp_stores (name, dimension, access_method, store_type, danger_rating, manager_name, manager_species) VALUES
    ('Bazar Glowny',  '3,5 Wymiar',             'Portal za Tesco w Kielcach, wt. o 3:00', 'interdimensional', 3, 'Pan Zygfryd Mroczny', 'Half-demon');
INSERT INTO oltp_stores (name, dimension, access_method, store_type, danger_rating, manager_name, manager_species) VALUES
    ('Sklep Snow',    'Przestrzen Miedzy Snami', 'Zasniej myslac o zakupach po serze',      'dreamscape',       2, 'Pani Oneiria Nicosc', 'Dream Weaver');
INSERT INTO oltp_stores (name, dimension, access_method, store_type, danger_rating, manager_name, manager_species) VALUES
    ('Kiosk Prozni',  'Anty-Wszechswiat B',      'Patrz w lustro o polnocy',                'void_kiosk',       4, 'Brak (zaginal)',       'Unknown Entity');

INSERT INTO oltp_customers (first_name, last_name, email, birth_date, city, region, soul_status, loyalty_tier, how_found_us) VALUES
    ('Krzysztof', 'Wieczny',       'k.wieczny@gmail.com',  DATE '1985-06-13', 'Kielce',   'Swietokrzyskie', 'partially_sold', 'silver_sinner',    'forbidden_grimoire');
INSERT INTO oltp_customers (first_name, last_name, email, birth_date, city, region, soul_status, loyalty_tier, how_found_us) VALUES
    ('Ryszard',   'Bez-Nadziei',   'ryszard@potepieni.pl', DATE '1968-11-01', 'Gdansk',   'Pomorskie',      'sold',           'platinum_heretic', 'word_of_mouth');
INSERT INTO oltp_customers (first_name, last_name, email, birth_date, city, region, soul_status, loyalty_tier, how_found_us) VALUES
    ('Zofia',     'Mroczna',       'z.mroczna@onet.pl',    DATE '2001-08-08', 'Warszawa', 'Mazowieckie',    'on_layaway',     'gold_apostate',    'ritual_gone_wrong');
INSERT INTO oltp_customers (first_name, last_name, email, birth_date, city, region, soul_status, loyalty_tier, how_found_us) VALUES
    ('Bogdan',    'Niesmiertelny', 'bogdan1337@gmail.com', DATE '1978-02-14', 'Lodz',     'Lodzkiego',      'intact',         'regular_damned',   'dark_web');

INSERT INTO oltp_orders (customer_id, store_id, order_date, status) VALUES (1, 1, DATE '2022-03-13', 'completed');
INSERT INTO oltp_orders (customer_id, store_id, order_date, status) VALUES (2, 3, DATE '2023-01-01', 'completed');
INSERT INTO oltp_orders (customer_id, store_id, order_date, status) VALUES (3, 1, DATE '2023-06-21', 'completed');
INSERT INTO oltp_orders (customer_id, store_id, order_date, status) VALUES (4, 2, DATE '2024-05-01', 'completed');
INSERT INTO oltp_orders (customer_id, store_id, order_date, status) VALUES (1, 2, DATE '2024-10-13', 'completed');
INSERT INTO oltp_orders (customer_id, store_id, order_date, status) VALUES (3, 3, DATE '2025-01-13', 'completed');

INSERT INTO oltp_order_items (order_id, product_id, quantity, unit_price, discount_pct, soul_fraction) VALUES (1, 5, 1,  1999.00,  0, 0.10);
INSERT INTO oltp_order_items (order_id, product_id, quantity, unit_price, discount_pct, soul_fraction) VALUES (2, 1, 1,  9999.99,  0, 1.00);
INSERT INTO oltp_order_items (order_id, product_id, quantity, unit_price, discount_pct, soul_fraction) VALUES (3, 4, 1, 250000.00, 0, 0.50);
INSERT INTO oltp_order_items (order_id, product_id, quantity, unit_price, discount_pct, soul_fraction) VALUES (3, 3, 2,  1299.99,  5, 0.00);
INSERT INTO oltp_order_items (order_id, product_id, quantity, unit_price, discount_pct, soul_fraction) VALUES (4, 2, 1, 99999.99,  0, 1.00);
INSERT INTO oltp_order_items (order_id, product_id, quantity, unit_price, discount_pct, soul_fraction) VALUES (5, 5, 1,  1999.00, 10, 0.10);
INSERT INTO oltp_order_items (order_id, product_id, quantity, unit_price, discount_pct, soul_fraction) VALUES (6, 6, 1, 500000.00, 0, 1.00);

INSERT INTO oltp_payments (order_id, payment_date, amount, currency, method) VALUES (1, DATE '2022-03-13',   1999.00, 'KARMA',  'blood_oath');
INSERT INTO oltp_payments (order_id, payment_date, amount, currency, method) VALUES (2, DATE '2023-01-01',   9999.99, 'SMOCZE', 'soul_transfer');
INSERT INTO oltp_payments (order_id, payment_date, amount, currency, method) VALUES (3, DATE '2023-06-21', 252599.98, 'TALARY', 'wish_token');
INSERT INTO oltp_payments (order_id, payment_date, amount, currency, method) VALUES (4, DATE '2024-05-01',  99999.99, 'SMOCZE', 'soul_transfer');
INSERT INTO oltp_payments (order_id, payment_date, amount, currency, method) VALUES (5, DATE '2024-10-13',   1799.10, 'KARMA',  'blik');
INSERT INTO oltp_payments (order_id, payment_date, amount, currency, method) VALUES (6, DATE '2025-01-13', 500000.00, 'TALARY', 'wish_token');

COMMIT;


-- ============================================================
-- [3] DWH - SCHEMAT GWIAZDY
-- ============================================================

-- dimDate (statyczny)
CREATE TABLE dimDate (
    date_key      NUMBER       PRIMARY KEY,   -- YYYYMMDD
    full_date     DATE         NOT NULL,
    day_of_month  NUMBER(2)    NOT NULL,
    day_name      VARCHAR2(15) NOT NULL,
    day_of_week   NUMBER(1)    NOT NULL,
    week_of_year  NUMBER(2)    NOT NULL,
    month_num     NUMBER(2)    NOT NULL,
    month_name    VARCHAR2(15) NOT NULL,
    quarter       NUMBER(1)    NOT NULL,
    year          NUMBER(4)    NOT NULL,
    is_weekend    NUMBER(1)    NOT NULL CONSTRAINT chk_wknd CHECK (is_weekend    IN (0,1)),
    is_full_moon  NUMBER(1)    DEFAULT 0    CONSTRAINT chk_moon CHECK (is_full_moon  IN (0,1)),
    is_cursed_day NUMBER(1)    DEFAULT 0    CONSTRAINT chk_cday CHECK (is_cursed_day IN (0,1))   -- piatek 13-go
);

-- dimCustomer - SCD Typ 2
-- Uzasadnienie: klient moze sprzedac dusze lub zmienic tier lojalnosciowy;
-- chcemy wiedziec jaki byl jego status W MOMENCIE kazdej transakcji.
CREATE TABLE dimCustomer (
    customer_key NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  NUMBER        NOT NULL,
    first_name   VARCHAR2(50)  NOT NULL,
    last_name    VARCHAR2(50)  NOT NULL,
    email        VARCHAR2(100) NOT NULL,
    city         VARCHAR2(50),
    region       VARCHAR2(50),
    age_group    VARCHAR2(20),
    soul_status  VARCHAR2(20)  NOT NULL,
    loyalty_tier VARCHAR2(30)  NOT NULL,
    how_found_us VARCHAR2(50),
    valid_from   DATE          NOT NULL,
    valid_to     DATE          DEFAULT DATE '9999-12-31',
    is_current   NUMBER(1)     DEFAULT 1 CONSTRAINT chk_curr2 CHECK (is_current IN (0,1))
);

-- dimProduct - SCD Typ 3
-- Uzasadnienie: produkty bywaja przeklasyfikowane (Kosmiczna Inspekcja Handlowa);
-- interesuje nas biezaca i poprzednia kategoria, pelna historia zbedna.
CREATE TABLE dimProduct (
    product_key        NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id         NUMBER        NOT NULL,
    name               VARCHAR2(150) NOT NULL,
    category_name      VARCHAR2(100) NOT NULL,
    prev_category_name VARCHAR2(100),          -- SCD Typ 3
    category_changed_at DATE,
    origin_realm       VARCHAR2(50),
    currency           VARCHAR2(10),
    is_cursed          NUMBER(1),
    danger_level       NUMBER(1),
    is_active          NUMBER(1)
);

-- dimStore - SCD Typ 1
-- Uzasadnienie: lokalizacja portalu zmienia sie (Kielce -> Radom),
-- ale historyczna lokalizacja nie ma wartosci analitycznej.
CREATE TABLE dimStore (
    store_key       NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id        NUMBER        NOT NULL,
    name            VARCHAR2(100) NOT NULL,
    dimension       VARCHAR2(80)  NOT NULL,
    access_method   VARCHAR2(80),
    store_type      VARCHAR2(30),
    danger_rating   NUMBER(1),
    manager_name    VARCHAR2(100),
    manager_species VARCHAR2(50)
);

-- dimPaymentMethod (statyczny)
CREATE TABLE dimPaymentMethod (
    payment_method_key NUMBER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    method_code        VARCHAR2(30) NOT NULL UNIQUE,
    method_name        VARCHAR2(50) NOT NULL,
    currency           VARCHAR2(10),
    is_soul_based      NUMBER(1)    DEFAULT 0 CONSTRAINT chk_sp CHECK (is_soul_based IN (0,1)),
    risk_level         VARCHAR2(10) DEFAULT 'medium'
        CONSTRAINT chk_rl CHECK (risk_level IN ('low','medium','high','eternal'))
);

-- factSales - granularnosc: jedna pozycja zamowienia (order_item)
CREATE TABLE factSales (
    sale_key            NUMBER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_key            NUMBER       NOT NULL REFERENCES dimDate(date_key),
    customer_key        NUMBER       NOT NULL REFERENCES dimCustomer(customer_key),
    product_key         NUMBER       NOT NULL REFERENCES dimProduct(product_key),
    store_key           NUMBER       NOT NULL REFERENCES dimStore(store_key),
    payment_method_key  NUMBER       NOT NULL REFERENCES dimPaymentMethod(payment_method_key),
    order_id            NUMBER       NOT NULL,
    item_id             NUMBER       NOT NULL,
    quantity            NUMBER       NOT NULL CONSTRAINT chk_fq CHECK (quantity > 0),
    unit_price          NUMBER(14,2) NOT NULL,
    discount_pct        NUMBER(5,2)  DEFAULT 0,
    revenue             NUMBER(14,2) NOT NULL,  -- quantity * unit_price * (1 - discount_pct/100)
    cost                NUMBER(14,2) NOT NULL,
    profit              NUMBER(14,2) NOT NULL,  -- revenue - cost
    soul_fraction       NUMBER(5,4)  DEFAULT 0,
    soul_equivalent_usd NUMBER(14,2) DEFAULT 0  -- kurs: 1 smocza moneta = 666 000 USD (Q1 2025)
);

-- indeksy B-tree
CREATE INDEX idx_fs_date  ON factSales(date_key);
CREATE INDEX idx_fs_cust  ON factSales(customer_key);
CREATE INDEX idx_fs_prod  ON factSales(product_key);
CREATE INDEX idx_fs_store ON factSales(store_key);
CREATE INDEX idx_fs_pay   ON factSales(payment_method_key);
CREATE INDEX idx_fs_order ON factSales(order_id);
CREATE INDEX idx_dim_yqm  ON dimDate(year, quarter, month_num);

-- indeksy bitmapowe (*) - niska kardynalnosc, srodowisko read-mostly
-- najpierw drop B-tree na tych samych kolumnach, potem bitmap
DROP INDEX idx_fs_store;
DROP INDEX idx_fs_pay;
CREATE BITMAP INDEX idx_bmp_store ON factSales(store_key);
CREATE BITMAP INDEX idx_bmp_pay   ON factSales(payment_method_key);


-- ============================================================
-- [4] ETL - ZASILANIE HURTOWNI
-- ============================================================

--  4.1 dimDate: kalendarz 2018-2025
DECLARE
    v_date DATE := DATE '2018-01-01';
    v_dow  NUMBER;
BEGIN
    WHILE v_date <= DATE '2025-12-31' LOOP
        v_dow := TO_NUMBER(TO_CHAR(v_date, 'D'));
        BEGIN
            INSERT INTO dimDate (
                date_key, full_date,
                day_of_month, day_name, day_of_week,
                week_of_year, month_num, month_name,
                quarter, year,
                is_weekend, is_full_moon, is_cursed_day
            ) VALUES (
                TO_NUMBER(TO_CHAR(v_date,'YYYYMMDD')),
                v_date,
                TO_NUMBER(TO_CHAR(v_date,'DD')),
                TO_CHAR(v_date,'DAY','NLS_DATE_LANGUAGE=POLISH'),
                v_dow,
                TO_NUMBER(TO_CHAR(v_date,'IW')),
                TO_NUMBER(TO_CHAR(v_date,'MM')),
                TO_CHAR(v_date,'MONTH','NLS_DATE_LANGUAGE=POLISH'),
                TO_NUMBER(TO_CHAR(v_date,'Q')),
                TO_NUMBER(TO_CHAR(v_date,'YYYY')),
                CASE WHEN v_dow IN (1,7) THEN 1 ELSE 0 END,
                CASE WHEN MOD(TRUNC(v_date) - DATE '2018-01-02', 29) < 1 THEN 1 ELSE 0 END,
                CASE WHEN v_dow = 6 AND TO_CHAR(v_date,'DD') = '13' THEN 1 ELSE 0 END
            );
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;
        v_date := v_date + 1;
    END LOOP;
    COMMIT;
END;
/

-- 4.2 dimPaymentMethod: slownik
INSERT INTO dimPaymentMethod (method_code, method_name, currency, is_soul_based, risk_level)
SELECT mc, mn, cur, sb, rl FROM (
    SELECT 'soul_transfer' mc,'Przelew Smoczymi Monetami' mn,'SMOCZE' cur, 1 sb,'eternal' rl FROM DUAL UNION ALL
    SELECT 'golden_coins',    'Zlote Monety',               'GOLD',   0,   'medium'           FROM DUAL UNION ALL
    SELECT 'karma_points',    'Punkty Karmiczne',           'KARMA',  0,   'high'             FROM DUAL UNION ALL
    SELECT 'blood_oath',      'Przysiega Krwi',             'SMOCZE', 1,   'eternal'          FROM DUAL UNION ALL
    SELECT 'blik',            'BLIK',                       'USD',    0,   'low'              FROM DUAL UNION ALL
    SELECT 'dark_card',       'Ciemna Karta',               'USD',    0,   'high'             FROM DUAL UNION ALL
    SELECT 'wish_token',      'Talary Wyspy Wielkanocnej',  'TALARY', 0,   'eternal'          FROM DUAL
) s WHERE NOT EXISTS (SELECT 1 FROM dimPaymentMethod d WHERE d.method_code = s.mc);
COMMIT;

--  4.3 dimStore - SCD Typ 1: MERGE nadpisuje bez historii
MERGE INTO dimStore tgt
USING (SELECT store_id,name,dimension,access_method,store_type,
              danger_rating,manager_name,manager_species
       FROM oltp_stores WHERE is_open=1) src
ON (tgt.store_id = src.store_id)
WHEN MATCHED THEN UPDATE SET
    tgt.name=src.name, tgt.dimension=src.dimension, tgt.access_method=src.access_method,
    tgt.store_type=src.store_type, tgt.danger_rating=src.danger_rating,
    tgt.manager_name=src.manager_name, tgt.manager_species=src.manager_species
WHEN NOT MATCHED THEN INSERT
    (store_id,name,dimension,access_method,store_type,danger_rating,manager_name,manager_species)
    VALUES (src.store_id,src.name,src.dimension,src.access_method,
            src.store_type,src.danger_rating,src.manager_name,src.manager_species);
COMMIT;

--  4.4 dimProduct - SCD Typ 3: zachowuje poprzednia kategorie przy zmianie
MERGE INTO dimProduct tgt
USING (SELECT p.product_id, p.name, c.name AS cat,
              p.origin_realm, p.currency, p.is_cursed, c.danger_level, p.is_active
       FROM oltp_products p JOIN oltp_categories c ON p.category_id=c.category_id) src
ON (tgt.product_id = src.product_id)
WHEN MATCHED THEN UPDATE SET
    tgt.name             = src.name,
    tgt.prev_category_name   = CASE WHEN tgt.category_name <> src.cat
                                    THEN tgt.category_name ELSE tgt.prev_category_name END,
    tgt.category_changed_at  = CASE WHEN tgt.category_name <> src.cat
                                    THEN SYSDATE ELSE tgt.category_changed_at END,
    tgt.category_name    = src.cat,
    tgt.origin_realm=src.origin_realm, tgt.currency=src.currency,
    tgt.is_cursed=src.is_cursed, tgt.danger_level=src.danger_level, tgt.is_active=src.is_active
WHEN NOT MATCHED THEN INSERT
    (product_id,name,category_name,prev_category_name,category_changed_at,
     origin_realm,currency,is_cursed,danger_level,is_active)
    VALUES (src.product_id,src.name,src.cat,NULL,NULL,
            src.origin_realm,src.currency,src.is_cursed,src.danger_level,src.is_active);
COMMIT;

--  4.5 dimCustomer - SCD Typ 2
-- Krok A: zamknij zmienione rekordy (valid_to = wczoraj, is_current = 0)
-- Uzywamy UPDATE zamiast MERGE bo Oracle nie pozwala updatowac kolumny z klauzuli ON
UPDATE dimCustomer tgt
SET tgt.valid_to   = SYSDATE - 1,
    tgt.is_current = 0
WHERE tgt.is_current = 1
  AND EXISTS (
      SELECT 1 FROM oltp_customers src
      WHERE src.customer_id  = tgt.customer_id
        AND src.is_banned    = 0
        AND (src.soul_status <> tgt.soul_status
         OR  src.loyalty_tier <> tgt.loyalty_tier)
  );

-- Krok B: wstaw nowe/zmienione rekordy
INSERT INTO dimCustomer
    (customer_id,first_name,last_name,email,city,region,age_group,
     soul_status,loyalty_tier,how_found_us,valid_from,valid_to,is_current)
SELECT c.customer_id, c.first_name, c.last_name, c.email, c.city, c.region,
       CASE WHEN MONTHS_BETWEEN(SYSDATE,c.birth_date)/12 < 26 THEN '18-25'
            WHEN MONTHS_BETWEEN(SYSDATE,c.birth_date)/12 < 36 THEN '26-35'
            WHEN MONTHS_BETWEEN(SYSDATE,c.birth_date)/12 < 51 THEN '36-50'
            WHEN MONTHS_BETWEEN(SYSDATE,c.birth_date)/12 < 66 THEN '51-65'
            WHEN c.birth_date IS NOT NULL THEN '66+' ELSE 'Nieznany' END,
       NVL(c.soul_status,'intact'), NVL(c.loyalty_tier,'cursed_newcomer'),
       NVL(c.how_found_us,'forbidden_grimoire'),
       SYSDATE, DATE '9999-12-31', 1
FROM oltp_customers c
WHERE c.is_banned=0
  AND NOT EXISTS (SELECT 1 FROM dimCustomer dc
                  WHERE dc.customer_id=c.customer_id AND dc.is_current=1);
COMMIT;

--  4.6 factSales: NOT EXISTS = ladowanie przyrostowe, pomija juz zaladowane
INSERT INTO factSales
    (date_key,customer_key,product_key,store_key,payment_method_key,
     order_id,item_id,quantity,unit_price,discount_pct,
     revenue,cost,profit,soul_fraction,soul_equivalent_usd)
SELECT
    TO_NUMBER(TO_CHAR(o.order_date,'YYYYMMDD')),
    dc.customer_key, dp.product_key, ds.store_key, dpm.payment_method_key,
    o.order_id, oi.item_id, oi.quantity, oi.unit_price, NVL(oi.discount_pct,0),
    ROUND(oi.quantity * oi.unit_price * (1 - NVL(oi.discount_pct,0)/100), 2),
    ROUND(oi.quantity * p.unit_cost, 2),
    ROUND(oi.quantity * oi.unit_price * (1 - NVL(oi.discount_pct,0)/100)
          - oi.quantity * p.unit_cost, 2),
    NVL(oi.soul_fraction,0),
    ROUND(NVL(oi.soul_fraction,0) * 666000, 2)
FROM oltp_order_items oi
JOIN oltp_orders      o   ON oi.order_id  = o.order_id
JOIN oltp_products    p   ON oi.product_id = p.product_id
JOIN oltp_payments    pay ON o.order_id   = pay.order_id
JOIN dimCustomer      dc  ON o.customer_id = dc.customer_id
                          AND o.order_date BETWEEN dc.valid_from AND dc.valid_to
JOIN dimProduct       dp  ON oi.product_id  = dp.product_id
JOIN dimStore         ds  ON o.store_id     = ds.store_id
JOIN dimPaymentMethod dpm ON pay.method     = dpm.method_code
WHERE o.status <> 'cancelled'
  AND NOT EXISTS (SELECT 1 FROM factSales fs WHERE fs.item_id = oi.item_id);
COMMIT;


-- ============================================================
-- [5] ANALITYKA WIELOWYMIAROWA
-- ============================================================

--  5.1 Przychod i zysk wg roku
SELECT d.year, COUNT(*) transakcje, SUM(f.quantity) sztuki,
       ROUND(SUM(f.revenue),2) przychod, ROUND(SUM(f.profit),2) zysk,
       ROUND(AVG(f.revenue),2) avg_pozycja
FROM factSales f JOIN dimDate d ON f.date_key=d.date_key
GROUP BY d.year ORDER BY d.year;

--  5.2 ROLLUP: rok > kwartal > miesiac
SELECT d.year, d.quarter, d.month_num,
       ROUND(SUM(f.revenue),2) przychod, ROUND(SUM(f.profit),2) zysk
FROM factSales f JOIN dimDate d ON f.date_key=d.date_key
GROUP BY ROLLUP(d.year, d.quarter, d.month_num)
ORDER BY d.year NULLS LAST, d.quarter NULLS LAST, d.month_num NULLS LAST;

--  5.3 ROLLUP: kategoria > produkt
SELECT p.category_name, p.name produkt,
       ROUND(SUM(f.revenue),2) przychod, SUM(f.quantity) sztuki
FROM factSales f JOIN dimProduct p ON f.product_key=p.product_key
GROUP BY ROLLUP(p.category_name, p.name)
ORDER BY p.category_name NULLS LAST, przychod DESC NULLS LAST;

--  5.4 CUBE: rok x kategoria x wymiar sklepu
SELECT d.year, p.category_name, s.dimension,
       ROUND(SUM(f.revenue),2) przychod, COUNT(*) transakcje,
       GROUPING(d.year) g_rok, GROUPING(p.category_name) g_kat, GROUPING(s.dimension) g_wym
FROM factSales f
JOIN dimDate    d ON f.date_key    = d.date_key
JOIN dimProduct p ON f.product_key = p.product_key
JOIN dimStore   s ON f.store_key   = s.store_key
GROUP BY CUBE(d.year, p.category_name, s.dimension)
ORDER BY d.year NULLS LAST, p.category_name NULLS LAST;

--  5.5 GROUPING SETS: wybrane przekroje
SELECT d.year, d.quarter, p.category_name, c.loyalty_tier,
       ROUND(SUM(f.revenue),2) przychod
FROM factSales f
JOIN dimDate     d ON f.date_key     = d.date_key
JOIN dimProduct  p ON f.product_key  = p.product_key
JOIN dimCustomer c ON f.customer_key = c.customer_key
GROUP BY GROUPING SETS ((d.year,d.quarter),(p.category_name),(c.loyalty_tier),())
ORDER BY d.year NULLS LAST, d.quarter NULLS LAST;

--  5.6 Ranking produktow wg roku (RANK, DENSE_RANK, ROW_NUMBER)
SELECT d.year, p.name, ROUND(SUM(f.revenue),2) przychod,
       RANK()       OVER (PARTITION BY d.year ORDER BY SUM(f.revenue) DESC) rnk,
       DENSE_RANK() OVER (PARTITION BY d.year ORDER BY SUM(f.revenue) DESC) drnk,
       ROW_NUMBER() OVER (PARTITION BY d.year ORDER BY SUM(f.revenue) DESC) rn
FROM factSales f
JOIN dimDate    d ON f.date_key    = d.date_key
JOIN dimProduct p ON f.product_key = p.product_key
GROUP BY d.year, p.name ORDER BY d.year, rnk;

--  5.7 Sprzedaz skumulowana YTD (SUM OVER)
SELECT d.year, d.month_num,
       ROUND(SUM(f.revenue),2) miesiac,
       ROUND(SUM(SUM(f.revenue)) OVER (
           PARTITION BY d.year ORDER BY d.month_num
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),2) ytd
FROM factSales f JOIN dimDate d ON f.date_key=d.date_key
GROUP BY d.year, d.month_num ORDER BY d.year, d.month_num;

--  5.8 MoM i YoY (LAG)
SELECT rok, miesiac, przychod,
       LAG(przychod) OVER (ORDER BY rok,miesiac) poprzedni,
       ROUND((przychod - LAG(przychod) OVER (ORDER BY rok,miesiac))
           / NULLIF(LAG(przychod) OVER (ORDER BY rok,miesiac),0)*100,2) mom_pct
FROM (SELECT d.year rok, d.month_num miesiac, ROUND(SUM(f.revenue),2) przychod
      FROM factSales f JOIN dimDate d ON f.date_key=d.date_key
      GROUP BY d.year, d.month_num)
ORDER BY rok, miesiac;

--  5.9 Udzial procentowy globalny i kategoryjny
SELECT p.category_name, p.name,
       ROUND(SUM(f.revenue),2) przychod,
       ROUND(SUM(f.revenue)/SUM(SUM(f.revenue)) OVER ()*100,2)                             udzial_global_pct,
       ROUND(SUM(f.revenue)/SUM(SUM(f.revenue)) OVER (PARTITION BY p.category_name)*100,2) udzial_kat_pct
FROM factSales f JOIN dimProduct p ON f.product_key=p.product_key
GROUP BY p.category_name, p.name ORDER BY p.category_name, przychod DESC;

--  5.10 Wykrywanie anomalii (STDDEV OVER, Z-score)
SELECT rok, miesiac, przychod,
       ROUND(srednia,2) srednia, ROUND(odch_std,2) std,
       ROUND(ABS(przychod-srednia)/NULLIF(odch_std,0),2) z_score,
       CASE WHEN ABS(przychod-srednia) > 2*odch_std THEN 'ANOMALIA!' ELSE 'OK' END status
FROM (SELECT d.year rok, d.month_num miesiac, ROUND(SUM(f.revenue),2) przychod,
             AVG(SUM(f.revenue))    OVER () srednia,
             STDDEV(SUM(f.revenue)) OVER () odch_std
      FROM factSales f JOIN dimDate d ON f.date_key=d.date_key
      GROUP BY d.year, d.month_num)
ORDER BY z_score DESC;


-- ============================================================
-- [6] OPTYMALIZACJA (*)
-- ============================================================

CREATE TABLE factSales_partitioned (
    sale_key           NUMBER GENERATED ALWAYS AS IDENTITY,
    date_key           NUMBER NOT NULL,
    customer_key       NUMBER NOT NULL,
    product_key        NUMBER NOT NULL,
    store_key          NUMBER NOT NULL,
    payment_method_key NUMBER NOT NULL,
    order_id           NUMBER NOT NULL,
    item_id            NUMBER NOT NULL,
    quantity           NUMBER NOT NULL,
    unit_price         NUMBER(14,2) NOT NULL,
    discount_pct       NUMBER(5,2)  DEFAULT 0,
    revenue            NUMBER(14,2) NOT NULL,
    cost               NUMBER(14,2) NOT NULL,
    profit             NUMBER(14,2) NOT NULL,
    soul_fraction      NUMBER(5,4)  DEFAULT 0,
    soul_equivalent_usd NUMBER(14,2) DEFAULT 0,
    sale_year          NUMBER(4)    NOT NULL
)
PARTITION BY RANGE (sale_year) (
    PARTITION p2018 VALUES LESS THAN (2019),
    PARTITION p2019 VALUES LESS THAN (2020),
    PARTITION p2020 VALUES LESS THAN (2021),
    PARTITION p2021 VALUES LESS THAN (2022),
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);

-- Analiza planu wykonania
EXPLAIN PLAN FOR
SELECT d.year, p.category_name, s.dimension, ROUND(SUM(f.revenue),2) przychod
FROM factSales f
JOIN dimDate    d ON f.date_key    = d.date_key
JOIN dimProduct p ON f.product_key = p.product_key
JOIN dimStore   s ON f.store_key   = s.store_key
GROUP BY CUBE(d.year, p.category_name, s.dimension);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'ALL'));

-- Aktualizacja statystyk optymalizatora
BEGIN DBMS_STATS.GATHER_TABLE_STATS(USER,'FACTSALES',  CASCADE=>TRUE,DEGREE=>4); END;
/
BEGIN DBMS_STATS.GATHER_TABLE_STATS(USER,'DIMDATE',    CASCADE=>TRUE); END;
/
BEGIN DBMS_STATS.GATHER_TABLE_STATS(USER,'DIMCUSTOMER',CASCADE=>TRUE); END;
/
BEGIN DBMS_STATS.GATHER_TABLE_STATS(USER,'DIMPRODUCT', CASCADE=>TRUE); END;
/
BEGIN DBMS_STATS.GATHER_TABLE_STATS(USER,'DIMSTORE',   CASCADE=>TRUE); END;
/