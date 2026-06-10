
CREATE DATABASE netflix_db;

USE netflix_db;
DROP TABLE IF EXISTS netflix;
CREATE TABLE netflix (
    show_id      VARCHAR(5),
    type         VARCHAR(10),
    title        VARCHAR(250),
    director     VARCHAR(550),
    casts        VARCHAR(1050),
    country      VARCHAR(550),
    date_added   VARCHAR(55),
    release_year INT,
    rating       VARCHAR(15),
    duration     VARCHAR(15),
    listed_in    VARCHAR(250),
    description  VARCHAR(550)
);

ALTER TABLE netflix 
MODIFY show_id varchar(20);

LOAD DATA INFILE 'path\\to\\netflix_titles.csv'
INTO TABLE netflix
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(show_id, type, title, director, casts, country, date_added,
 release_year, 
 rating, duration, 
 listed_in, description);

-- =====================================
-- INITIAL DATA EXPLORATION
-- =====================================

Select COUNT(*) as total_records
FROM netflix;

Select * 
FROM netflix limit 10 ;

Select * 
FROM netflix 
order by date_added desc limit 10 ;

Select distinct type
FROM netflix;

-- =====================================
-- BUSINESS PROBLEM SOLVING QUERIES
-- =====================================

-- 1. Count the number of Movies vs TV Shows
Select type,count(*) as total_records
FROM netflix
GROUP BY type;

-- 2. Find the most common rating for movies and TV shows
WITH total_content as (
		Select type,rating,count(*) as total
		FROM netflix
		GROUP BY type,rating
)
Select type,rating
FROM(
Select type,rating,
RANK() OVER(partition by type order by total desc) as rnk
FROM total_content
)t
WHERE 
	rnk = 1;

-- 3. List all movies released in a specific year (e.g., 2020)
Select *
FROM netflix
WHERE 
	type = 'Movie'
	AND 
    release_year = 2020;

-- 4. Find the top 5 countries with the most content on Netflix

WITH split_string as(
	Select n.show_id,trim(j.country) as country
	FROM netflix n,
	json_table(	
		CONCAT('["',replace(country,',','","'),'"]'),
		'$[*]' COLUMNS(country varchar(100) PATH '$')
		) as j
	WHERE 
		n.country IS NOT NULL
		AND trim(n.country) <> ''
		AND trim(j.country) <> ''
        AND lower(trim(j.country)) <> 'null'
)
Select country ,total_content
FROM 
(Select country,COUNT(*) as total_content,
RANK() OVER(order by COUNT(*) desc ) as ranking
FROM split_string
GROUP BY country)t
WHERE 
	ranking in (1,2,3,4,5);

-- 5. Identify the longest movie

Alter table netflix add column duration_num int ;-- Added a new column "duration_num"

UPDATE netflix
SET duration_num  = regexp_substr(trim(duration),'[0-9]+')  -- extracted numerical values from the string
WHERE duration like '%min%'; 

Select title,duration_num
FROM netflix
WHERE type = 'movie' 
ORDER BY duration_num desc
LIMIT 1;

-- 6. Find content added in the last 5 years
WITH highest_year AS
	(Select date_added,title,MAX(date_added) OVER()as max_year
	FROM
	(Select str_to_date(date_added,'%M %d,%Y') as date_added,title
	FROM netflix
	WHERE date_added IS NOT NULL
	)t
    )
Select date_added,title
FROM highest_year 
WHERE
	date_added >= date_sub(max_year,INTERVAL 5 YEAR)
ORDER BY date_added;

-- 7. Find all the movies/TV shows by director 'Rajiv Chilaka'!
Select title,director
FROM netflix
WHERE director like '%Rajiv Chilaka%';

-- 8. List all TV shows with more than 5 seasons
UPDATE netflix
SET duration_num = CAST(substring_index(trim(duration),' ',1) AS UNSIGNED) -- Updated numeric value into duration_num
WHERE duration LIKE '%Season%';

Select * 
FROM netflix
WHERE 
	type = 'TV Show'
    AND
	duration_num > 5
ORDER BY duration_num ASC;

-- 9. Count the number of content items in each genre
WITH split_genre as (
	Select trim(j.genre) as genre,show_id
	FROM netflix n,
	JSON_TABLE(CONCAT('["',replace(n.listed_in,',','","'),'"]'),
	'$[*]' COLUMNS(genre varchar(100) PATH '$')
	) j
)
Select genre,COUNT(*) AS total_content
FROM split_genre
GROUP BY genre
ORDER BY total_content DESC

--  Find the top 5 years with the highest number of Indian content added to Netflix.

WITH split_country AS (
	Select trim(j.Country) as Country,show_id,DATE_FORMAT(STR_TO_DATE(date_added,'%M %d,%Y'),'%Y') as years
	FROM netflix n,
	JSON_TABLE(CONCAT('["',REPLACE(n.country,',','","'),'"]'),
	'$[*]' COLUMNS(Country varchar(100) PATH '$')
	) j
    WHERE 
		trim(j.country) = 'India'
		AND j.country IS NOT NULL
		AND trim(j.country) <> ''
		AND trim(n.country) <> ''
		AND trim(n.country) IS NOT NULL
        AND trim(n.date_added) IS NOT NULL
)
Select years,Country,count(*) as Total
FROM split_country
GROUP BY years,Country
ORDER BY Total desc
LIMIT 5

-- 11. List all movies that are documentaries
WITH split_genre AS (
	Select n.show_id as show_id,n.type as type,trim(genre) as genre
	FROM netflix n,
	JSON_TABLE (CONCAT('["',REPLACE(listed_in,',','","'),'"]'),
	'$[*]' COLUMNS(genre varchar(100) PATH '$')
	) j
	WHERE 
		j.genre IS NOT NULL
		AND j.genre <> ''
		AND n.listed_in <> ''
 )
Select genre,COUNT(show_id) as total_documentaries
FROM split_genre
WHERE 
	type = 'Movie' 
    AND genre = 'Documentaries'
GROUP BY genre

-- 12. Find all content without a director
Select *
FROM netflix
WHERE 
	director IS NULL
    OR director = ''
    OR director = ' '

-- 13. Find how many movies actor 'Salman Khan' appeared in last 10 years!.
WITH split_casts AS(
	Select trim(actor) as actor,n.title as title,
    n.release_year as release_year,n.date_added as date_added
	FROM netflix n,
	JSON_TABLE (CONCAT('["',REPLACE(REPLACE(n.casts,'"','\\"'),',','","'),'"]'),
		'$[*]' COLUMNS(actor varchar(100) PATH '$')
		) j
	WHERE trim(j.actor) = 'Salman Khan'
    AND type = 'Movie'
    AND n.casts IS NOT NULL
    AND n.casts <> ''
    AND j.actor <> ''
)
Select COUNT(DISTINCT title) as Total_movies
FROM split_casts
WHERE release_year >= YEAR(CURDATE()) - 10

-- 14. Find the top 10 actors who have appeared in the highest number of movies produced in India.
WITH split_casts AS(	
    Select trim(actor) as actor,n.title as title,
    n.country as country,n.type as type
	FROM netflix n,
	JSON_TABLE (CONCAT('["',REPLACE(REPLACE(n.casts,'"','\\"'),',','","'),'"]'),
		'$[*]' COLUMNS(actor varchar(100) PATH '$')
		) j
    WHERE n.country <> ''
    AND n.casts <> ''
    AND j.actor <> ''
)
Select actor,country,COUNT(DISTINCT title) as total_movies
FROM split_casts	
WHERE country LIKE '%India%'
AND type = 'Movie'
GROUP BY actor,country
ORDER BY total_movies DESC
LIMIT 5

-- 15.
-- Categorize the content based on the presence of the keywords 'kill' and 'violence' in 
-- the description field. Label content containing these keywords as 'Bad' and all other 
-- content as 'Good'. Count how many items fall into each category.

Select 
CASE 
	WHEN description REGEXP '\\bkill\\b' OR description regexp '\\bviolence\\b' THEN 'Violent_Content' 
	ELSE 'Non-violent_Content' 
	END as Category,
    COUNT(*) as total_content
FROM netflix
GROUP BY category;








