-- Monday Coffee SCHEMAS --

DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS city;

-- Import Rules
-- 1st import to city
-- 2nd import to products
-- 3rd import to customers
-- 4th import to sales


CREATE TABLE city
(
	city_id	INT PRIMARY KEY,
	city_name VARCHAR(15),	
	population	BIGINT,
	estimated_rent	FLOAT,
	city_rank INT
);

CREATE TABLE customers
(
	customer_id INT PRIMARY KEY,	
	customer_name VARCHAR(25),	
	city_id INT,
	CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES city(city_id)
);


CREATE TABLE products
(
	product_id	INT PRIMARY KEY,
	product_name VARCHAR(35),	
	Price float
);


CREATE TABLE sales
(
	sale_id	INT PRIMARY KEY,
	sale_date	date,
	product_id	INT,
	customer_id	INT,
	total FLOAT,
	rating INT,
	CONSTRAINT fk_products FOREIGN KEY (product_id) REFERENCES products(product_id),
	CONSTRAINT fk_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id) 
);

-- END of SCHEMAS --

SELECT * FROM city;
SELECT * FROM customers;
SELECT * FROM products;
SELECT * FROM sales;

-- Business Problems --

-- Problem 1
-- How many people in each city are estimated to consume coffee, given that 25% of the population does?

SELECT city_name, population, population*0.25 AS coffee_drinkers
FROM city;

-- Problem 2
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

SELECT SUM(total) AS total_sales
FROM sales AS s
WHERE sale_date BETWEEN '2023-10-01' AND '2023-12-31';

-- Problem 3
-- How many units of each coffee product have been sold?

SELECT p.product_name, COUNT(s.product_id) AS units_sold
FROM products AS p
LEFT JOIN sales AS s
ON p.product_id = s.product_id
GROUP BY p.product_name
ORDER BY units_sold DESC;

-- Problem 4
-- What is the average sales amount per customer in each city?

WITH cust_cte
AS
	(SELECT
		c.city_name,
		cs.customer_name,
		SUM(total) AS customer_sales,
		COUNT(DISTINCT customer_name) AS customer_count
	FROM city AS c
	LEFT JOIN customers AS cs
	ON c.city_id = cs.city_id
	LEFT JOIN sales AS s
	ON cs.customer_id = s.customer_id
	GROUP BY c.city_name, cs.customer_name
	ORDER BY city_name)
SELECT city_name, ROUND(AVG(customer_sales)::numeric, 2) AS avg_customer_sales
FROM cust_cte
GROUP BY city_name
ORDER BY avg_customer_sales DESC;

-- Problem 5
-- Provide a list of cities along with their populations and estimated coffee consumers.
-- return city_name, total current customers, estimated coffee consumers (25%)

WITH est
AS
	(SELECT city_name, population, population*0.25 AS coffee_drinkers
	FROM city),
cus
AS
	(SELECT city_name, COUNT(cs.customer_id) AS customer_count
	FROM city AS c
	JOIN customers AS cs
	ON c.city_id = cs.city_id
	GROUP BY c.city_name)
SELECT est.city_name, cus.customer_count, est.coffee_drinkers
FROM est
JOIN cus
ON est.city_name = cus.city_name;

-- Problem 6
-- What are the top 3 selling products in each city based on sales volume?

WITH rank_cte
AS
	(SELECT city_name,
			product_name,
			SUM(total) AS total_sales,
			RANK() OVER(PARTITION BY city_name ORDER BY SUM(total) DESC) AS product_rank
	FROM sales AS s
	JOIN products AS p
	ON s.product_id = p.product_id
	JOIN customers AS cs
	ON s.customer_id = cs.customer_id
	JOIN city AS c
	ON c.city_id = cs.city_id
	GROUP BY city_name, product_name)
SELECT city_name, product_name, total_sales, product_rank
FROM rank_cte
WHERE product_rank <= 3;

-- Problem 7
-- How many unique customers are there in each city who have purchased coffee products?

SELECT city_name, COUNT(DISTINCT s.customer_id) AS customer_count
FROM city AS c
JOIN customers AS cs
ON c.city_id = cs.city_id
RIGHT JOIN sales AS s
ON cs.customer_id = s.customer_id
WHERE product_id <= 14
GROUP BY city_name
ORDER BY customer_count DESC;

-- Problem 8
-- Find each city and their average sale per customer and avg rent per customer.

SELECT 	city_name,
		SUM(total) AS total_sales,
		COUNT(DISTINCT s.customer_id) AS customer_count,
		AVG(estimated_rent) AS est_rent,
		ROUND(SUM(total)/COUNT(DISTINCT s.customer_id)) AS sale_per_customer,
		ROUND(AVG(estimated_rent)/COUNT(DISTINCT s.customer_id)) AS rent_per_customer
FROM city AS c
JOIN customers AS cs
ON c.city_id = cs.city_id
RIGHT JOIN sales AS s
ON cs.customer_id = s.customer_id
GROUP BY city_name;

-- Problem 9
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city

WITH current_month
AS
	(SELECT
			city_name,
			EXTRACT(YEAR FROM sale_date) AS year,
			EXTRACT(MONTH FROM sale_date) AS month,
			SUM(total) AS total_sales,
			LAG(SUM(total), 1) OVER(PARTITION BY city_name ORDER BY 2, 3) AS prev_month_sales
	FROM sales AS s
	LEFT JOIN customers AS cs
	ON s.customer_id = cs.customer_id
	LEFT JOIN city AS c
	ON cs.city_id = c.city_id
	GROUP BY city_name, year, month
	ORDER BY city_name, year, month)
SELECT 	city_name,
		year,
		month,
		total_sales,
		prev_month_sales,
		ROUND(((total_sales - prev_month_sales)/prev_month_sales*100)::numeric, 1) AS percent_change
FROM current_month;