SELECT TOP (1000) [Row_ID]
,[Order_ID]
,[Order_Date]
,[Ship_Date]
,[Ship_Mode]
,[Customer_ID]
,[Customer_Name]
,[Segment]
,[Country]
,[City]
,[State]
,[Postal_Code]
,[Region]
,[Product_ID]
,[Category]
,[Sub_Category]
,[Product_Name]
,[Sales]
FROM [superstore].[dbo].[sales]


SELECT top 10* FROM [superstore].[dbo].[sales]

SELECT count(*) FROM [superstore].[dbo].[sales]


SELECT distinct
     [Order_Date]
      ,[Ship_Date]
      ,[Ship_Mode]
      ,[Customer_ID]
      ,[Customer_Name]
      ,[Segment]
      ,[Country]
      ,[City]
      ,[State]
      ,[Postal_Code]
      ,[Region]
      ,[Product_ID]
      ,[Category]
      ,[Sub_Category]
      ,[Product_Name]
      ,[Sales]
FROM [superstore].[dbo].[sales]
where order_id = 'US-2015-150119'
and round(sales,2) = 281.37
and product_name = 'Global Leather Highback Executive Chair with Pneumatic Height Adjustment, Black'




SELECT order_id,sales
FROM [superstore].dbo.sales
group by order_id,sales
having count(*)>1


SELECT order_id,product_name,sales
FROM [superstore].dbo.sales
group by order_id,product_name,sales
having count(*)>1


/*

product
order
sale

*/


select distinct product_id  from [superstore].dbo.sales


select product_id,product_name
from (
select distinct 
    product_id, category, sub_category, product_name
from [superstore].dbo.sales
)x
group by product_id,product_name
having count(*) > 1


--prod id/prod name
--



--1849 product names = sub cat = cat
select *
from (
select distinct 
      product_name,category--, product_name
from [superstore].dbo.sales
)x
group by product_id,product_name
having count(*) > 1




select distinct 
      product_name
from [superstore].dbo.sales
group by product_name
having count(distinct product_id) > 1

--sales.product <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
--1893
--select ROW_NUMBER() over (order by product_id,product_name) product_id,*
select ROW_NUMBER() over (order by product_name) product_id,*
from (
select distinct 
    category, sub_category, product_name
from [superstore].dbo.sales
)x
--where product_name = '#10- 4 1/8" x 9 1/2" Recycled Envelopes'
order by 1



select distinct product_id  from [superstore].dbo.sales --1861
select distinct product_name,category,sub_category  from [superstore].dbo.sales --1849
select distinct category  from [superstore].dbo.sales
select distinct sub_category  from [superstore].dbo.sales


--sales.customer <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

--793

select row_number() over (order by customer_id) customer_id,* from(
select distinct customer_id,customer_name,segment
from [superstore].dbo.sales)x
order by 4

--sales.location <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

update [superstore].dbo.sales set postal_code = 11111 where city = 'Burlington' and state = 'Vermont'

--628
select row_number() over (order by postal_code) location_id,*  from(
select distinct country,city,state,postal_code,region
from [superstore].dbo.sales)x

order by 6

--sales.sales <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

select *
from [superstore].dbo.sales


select distinct row_id,order_id
from [superstore].dbo.sales

select distinct order_id
from [superstore].dbo.sales

select distinct order_id--,order_date,ship_mode,
   -- product
from [superstore].dbo.sales

select distinct order_id,product_name,customer_id,postal_code,sales
   -- product
from [superstore].dbo.sales
group by order_id,product_name,customer_id,postal_code,sales
having count(*)>1

select * 
from [superstore].dbo.sales
where order_id = 'US-2015-150119' and product_name = 'Global Leather Highback Executive Chair with Pneumatic Height Adjustment, Black' and customer_id = 'LB-16795' and postal_code = '43229'



select distinct *
   -- product
from [superstore].dbo.sales

-----------------------------------------------------------------------------------------------

-- sales / locations / customer / product

drop table if exists #sales
drop table if exists #location
drop table if exists #customer
drop table if exists #product


drop table sales.sales


select distinct 
    row_id sales_id,
    order_id,
    order_date,
    ship_date,
    ship_mode,
    product_name product_id,
    customer_id customer_id,
    postal_code location_id,
    sales
into #sales
from [superstore].dbo.sales


select row_number() over (order by postal_code) location_id,*  
into #location
from(
select distinct country,city,state,postal_code,region
from [superstore].dbo.sales)x
order by 1

select row_number() over (order by customer_key) customer_id,* 
into #customer
from(
select distinct customer_id customer_key,customer_name,segment
from [superstore].dbo.sales)x
order by 1


select ROW_NUMBER() over (order by product_name) product_id,*
into #product
from (
select distinct 
    category, sub_category, product_name
from [superstore].dbo.sales
)x
--where product_name = '#10- 4 1/8" x 9 1/2" Recycled Envelopes'
order by 1


update s set product_id = p.product_id 
from #sales s
join #product p
on s.product_id = p.product_name


update s set location_id = p.location_id 
from #sales s
join #location p
on s.location_id = p.postal_code

update s set customer_id = p.customer_id 
from #sales s
join #customer p
on s.customer_id = p.customer_key


select * 
from #sales s
join #product p
on p.product_id = s.product_id
join #location l
on l.location_id = s.location_id
join #customer c
on c.customer_id = s.customer_id



create table #sales as select * from #sales
create table #product as select * from #product
create table #sales as select * from #location
create table #customer as select * from #customer

select * from #sales s
select * from #product
select * from #location
select * from #customer

drop table sales.sales


select * into sales.sales from #sales
select * into sales.product from #product
select * into sales.location from #location
select * into sales.customer from #customer


select * from sales.sales 


select product_name,sum(s.Sales)
from sales.sales s
join sales.product p
on p.product_id = s.product_id
join sales.location l
on l.location_id = s.location_id
join sales.customer c
on c.customer_id = s.customer_id
group by product_name
order by 2 desc



select *
from sales.sales s
join sales.product p
on p.product_id = s.product_id
join sales.location l
on l.location_id = s.location_id
join sales.customer c
on c.customer_id = s.customer_id


select * from sales.sales
select * from sales.product
select * from sales.location
select * from sales.customer
