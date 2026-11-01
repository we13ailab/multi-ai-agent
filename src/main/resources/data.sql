-- ============================================================================
-- multi-ai-agent — startup seed data (MySQL)
--
-- Loaded automatically by Spring Boot on every startup:
--   * spring.sql.init.mode=always            (application.yaml)
--   * spring.jpa.defer-datasource-initialization=true ensures this script
--     runs AFTER Hibernate (ddl-auto: update) has created/updated the
--     `orders` and `refund_policy` tables.
--
-- Idempotent on every restart:
--   * orders        -> INSERT IGNORE: `order_id` is UNIQUE, so rows that
--                      already exist are skipped instead of duplicated.
--                      API-test mutations (e.g. a cancelled order) survive
--                      restarts untouched.
--   * refund_policy -> INSERT ... WHERE NOT EXISTS: no unique key on
--                      `orderStatus`, so each row is guarded manually.
--
-- NOTE on column names: PhysicalNamingStrategyStandardImpl keeps unannotated
-- camelCase field names as-is (customerName, orderStatus, ...). Only
-- `order_id` is explicitly mapped in OrderEntity.
--
-- The order_id values match the Postman collection variables
-- ({{orderId1}} = ORD-1001, {{orderId2}} = ORD-1002, {{orderId3}} = ORD-1003)
-- so multi-ai-agent.postman_collection.json works against this data as-is.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Orders — one row per scenario exercised by request.http / Postman
-- ----------------------------------------------------------------------------
INSERT IGNORE INTO orders (
    order_id, customerName, productName, status,
    currentLocation, expectedDelivery, totalAmount, paymentStatus
) VALUES
    -- Shipped: refund NOT eligible; cancellation blocked (OrderCannotBeCancelledException)
    ('ORD-1001', 'John Doe',    'iPhone 15',         'Shipped',    'Hyderabad',           '2026-11-05',   999.00, 'PAID'),
    -- Processing: refund eligible; cancellable (target of the "cancel order" Postman test)
    ('ORD-1002', 'Jane Smith',  'MacBook Pro',       'Processing', 'Warehouse - Mumbai',  '2026-11-10',  2499.00, 'PAID'),
    -- Shipped: used by the "cancel a SHIPPED order" negative test (expects failure)
    ('ORD-1003', 'Bob Brown',   'AirPods Pro',       'Shipped',    'Bengaluru',           '2026-11-03',   249.00, 'PAID'),
    -- Delivered: refund NOT eligible per policy (30-day return window case)
    ('ORD-1004', 'Alice Davis', 'Apple Watch',       'DELIVERED',  'Delivered - Pune',    '2026-10-20',   599.00, 'PAID'),
    -- Cancelled: refund eligible; expectedDelivery is NULL by design (matches cancelOrder behaviour)
    ('ORD-1005', 'Ravi Kumar',  'iPad Air',          'CANCELLED',  'Cancelled',           NULL,           749.00, 'REFUND_INITIATED'),
    -- Packed: deliberately has NO refund_policy row -> triggers
    -- RefundPolicyNotFoundException in the refund workflow (negative case)
    ('ORD-1006', 'Emma Wilson', 'Kindle Paperwhite', 'Packed',     'Delhi Hub',           '2026-11-08',   189.99, 'PAID');

-- ----------------------------------------------------------------------------
-- Refund policies — one row per order status the tools can look up
-- ----------------------------------------------------------------------------
INSERT INTO refund_policy (orderStatus, eligible, message)
SELECT 'Shipped', FALSE, 'Orders that have already been shipped cannot be refunded automatically. Contact support after delivery to arrange a return.'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM refund_policy WHERE orderStatus = 'Shipped');

INSERT INTO refund_policy (orderStatus, eligible, message)
SELECT 'Processing', TRUE, 'Orders still being processed are eligible for a full refund.'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM refund_policy WHERE orderStatus = 'Processing');

INSERT INTO refund_policy (orderStatus, eligible, message)
SELECT 'CANCELLED', TRUE, 'Cancelled orders are refunded to the original payment method within 5 business days.'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM refund_policy WHERE orderStatus = 'CANCELLED');

INSERT INTO refund_policy (orderStatus, eligible, message)
SELECT 'DELIVERED', FALSE, 'Delivered orders must be returned within 30 days to qualify for a refund.'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM refund_policy WHERE orderStatus = 'DELIVERED');
