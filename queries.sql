-- COMP3311 20T3 Assignment 2
-- By Sung Kuk Go (z5310199)

-- Q1: students who've studied many courses

create view Q1(unswid,name)
as
select distinct p.unswid, p.name
from course_enrolments c
    join people p on p.id = c.student
group by p.unswid, p.name
having count(c.course) > 65;

-- Q2: numbers of students, staff and both

create or replace view Q2(nstudents,nstaff,nboth)
as
select count(s.id), count(f.id), count(s.id = f.id)
from people p
    full join students s on s.id = p.id
    full join staff f on f.id = p.id;

-- Q3: prolific Course Convenor(s)

-- helper view for Q3 - finds the count of courses taught for all
-- course convenors
create or replace view Q3_helper(name,ncourses)
as
select p.name, count(p.name)
from people p
    full join staff s on s.id = p.id 
    full join course_staff c on c.staff = s.id
    full join staff_roles r on r.id = c.role
where r.name = 'Course Convenor'
group by p.name;

-- main view for Q3 - finds all the convenors with highest frequency of
-- courses taught
create or replace view Q3(name,ncourses)
as
select p.name, count(p.name)
from people p
    full join staff s on s.id = p.id 
    full join course_staff c on c.staff = s.id
    full join staff_roles r on r.id = c.role
where r.name = 'Course Convenor'
group by p.name
having count(p.name) >= all(select ncourses from Q3_helper);

-- Q4: Comp Sci students in 05s2 and 17s1

create or replace view Q4a(id,name)
as
select distinct p.unswid, p.name
from students s 
    join people p on s.id = p.id
    join program_enrolments e on s.id = e.student
    join programs pro on pro.id = e.program
    join terms t on t.id = e.term
where pro.code = '3978' and termname(t.id) = '05s2';

create or replace view Q4b(id,name)
as
select distinct p.unswid, p.name
from students s 
    join people p on s.id = p.id
    join program_enrolments e on s.id = e.student
    join programs pro on pro.id = e.program
    join terms t on t.id = e.term
where pro.code = '3778' and termname(t.id) = '17s1';

-- Q5: most "committee"d faculty

-- helper view for Q5 - finds the count of all committees for each
-- faculty
create or replace view Q5_helper(num)
as
select iden.lot
from orgunits o, (
    select facultyof(o.id) as val, count(facultyof(o.id)) as lot
    from orgunits o
        join orgUnit_types t on t.id = o.utype 
    where t.name = 'Committee'
    group by val
) iden
where iden.val = o.id;

-- main view for Q5 - finds all the faculties with highest number of 
-- committees
create or replace view Q5(name)
as
select o.name
from orgunits o, (
    select facultyof(o.id) as val, count(facultyof(o.id)) as lot
    from orgunits o
        join orgUnit_types t on t.id = o.utype 
    where t.name = 'Committee'
    group by val
    having count(facultyof(o.id)) >= all(select num from Q5_helper)
) iden
where iden.val = o.id;

-- Q6: nameOf function

create or replace function
   Q6(id integer) returns text
as $$
select name
from people
where people.id = $1
    or people.unswid = $1
$$ language sql;

-- Q7: offerings of a subject

create or replace function
   Q7(subject text)
     returns table (subject text, term text, convenor text)
as $$
select $1, termname(t.id), p.name
from subjects s
    join courses c on c.subject = s.id
    join terms t on t.id = c.term
    join course_staff cf on cf.course = c.id
    join staff_roles r on cf.role = r.id
    join staff sf on sf.id = cf.staff
    join people p on p.id = sf.id
where r.name = 'Course Convenor'
    and s.code = $1
$$ language sql;

-- Q8: transcript

create or replace function
   Q8(zid integer) returns setof TranscriptRecord
as $$
declare
    tpt TranscriptRecord%rowtype;
    checkid integer;
    weightedSumOfMarks integer := 0;
    totalUOCattempted integer := 0;
    UOCpassed integer := 0;
begin
    -- find if zid exists and insert into checkid
    select p.unswid into checkid
    from people p join students s on p.id = s.id
    where p.unswid = zid;

    -- raise exception if zid(checkid) does not exist
    if (checkid is null) then 
        raise exception 'Invalid student %', zid;
    end if;

    -- if zid exists, populate the return table
    for tpt in (
        select distinct s.code, termname(t.id), pro.code, 
            substring(s.name, 0, 21), e.mark, e.grade, s.uoc, t.starting
        from people p
            join students stu on stu.id = p.id
            join course_enrolments e on e.student = stu.id
            join courses c on e.course = c.id
            join terms t on  t.id = c.term
            join subjects s on s.id = c.subject
            join program_enrolments pe on pe.student = stu.id
            join programs pro on pro.id = pe.program
        where p.unswid = zid and pe.term = t.id
        order by t.starting, s.code ASC
    ) loop
        -- if mark exists, then calculate/update the total UOC passed and sum of marks
        if tpt.mark is not null then
            weightedSumOfMarks = weightedSumOfMarks + tpt.mark * tpt.uoc;
            UOCpassed = UOCpassed + tpt.uoc;
        end if;
        -- if grade is valid, calculate/update the total UOC attempted.
        -- Otherwise, return null
        if tpt.grade in ('SY', 'PT', 'PC', 'PS', 'CR', 'DN', 'HD', 'A', 
            'B', 'C', 'XE', 'T', 'PE', 'RC', 'RS') then 
            totalUOCattempted = totalUOCattempted + tpt.uoc;
        else 
            tpt.uoc = null;
        end if;
        return next tpt;
    end loop;
    -- if no subject code is retrieved, it means the student did not complete
    -- any courses yet so output null information on their transcript
    if (tpt.code is null) then
        select null, null, null, 'No WAM available', null, null, null
        into tpt.code, tpt.term, tpt.prog, tpt.name, tpt.mark, tpt.grade, tpt.uoc;
        return next tpt;
    -- otherwise, append wam and uoc information
    else 
        select null, null, null, 'Overall WAM/UOC', 
            round(weightedSumOfMarks::float/UOCpassed::float), 
            null, totalUOCattempted
        into tpt.code, tpt.term, tpt.prog, tpt.name, tpt.mark, tpt.grade, tpt.uoc;
        return next tpt;
    end if;
end;
$$ language plpgsql;

-- Q9: members of academic object group

create or replace function
   Q9(gid integer) returns setof AcObjRecord
as $$
declare
    abr AcObjRecord%rowtype;
    found_gtype text;
    found_gdefby text;
    child_id integer;
begin
    -- if gid does not exist, then raise error
    if not exists (select id from acad_object_groups where id = gid) then 
        raise exception 'No such group %', gid;
    end if;
    -- find the gtype and gdefby of the gid
    select gtype into found_gtype from acad_object_groups where id = gid;
    select gdefby into found_gdefby from acad_object_groups where id = gid;
    -- depending on gtype and gdefby, perform neccessary requirements
    if found_gtype = 'program' and found_gdefby <> 'pattern' then
        for abr in (
            select a.gtype, pro.code
            from acad_object_groups a
                join program_group_members p on p.ao_group = a.id
                join programs pro on pro.id = p.program
            where a.id = gid
        ) loop
            return next abr;
        end loop;
    elseif found_gtype = 'program' and found_gdefby = 'pattern' then
        for abr in (
            select a.gtype, regexp_split_to_table(a.definition, ',')
            from acad_object_groups a
            where a.id = gid
        ) loop
            return next abr;
        end loop;
    -- stream has no pattern case
    elseif found_gtype = 'stream' then
        for abr in (
            select a.gtype, str.code
            from acad_object_groups a
                join stream_group_members s on s.ao_group = a.id
                join streams str on str.id = s.stream
            where a.id = gid
        ) loop
            return next abr;
        end loop;
    elseif found_gtype = 'subject' and found_gdefby <> 'pattern' then
        for abr in (
            select a.gtype, sub.code
            from acad_object_groups a
                join subject_group_members s on s.ao_group = a.id
                join subjects sub on sub.id = s.subject
            where a.id = gid
        ) loop
            return next abr;
        end loop;
    elseif found_gtype = 'subject' and found_gdefby = 'pattern' then
        for abr in (
            select a.gtype, regexp_split_to_table(a.definition, ',')
            from acad_object_groups a
            where a.id = gid
        ) loop
            -- replace with appropriate characters so that regex can be 
            -- used efficiently
            abr.objcode = replace(abr.objcode, '#', '.');
            abr.objcode = replace(abr.objcode, '{', '(');
            abr.objcode = replace(abr.objcode, '}', ')');
            abr.objcode = replace(abr.objcode, ';', '|');
            for abr in (
                select abr.objtype, code
                from subjects
                where code ~ abr.objcode
            ) loop
                if abr.objcode !~ '(FREE|GEN|F=)' or abr.objcode <> '' then 
                    return next abr;
                end if;
            end loop;
        end loop;
    end if;
    -- use abr as placeholder to recursively scan for child groups
    for abr in select id::text, null from acad_object_groups where parent = gid
    loop 
        if abr.objtype is not null then
            return query select * from Q9(abr.objtype::int);
        end if;
    end loop;
end;
$$ language plpgsql;

-- Q10: follow-on courses

create or replace function
   Q10(code text) returns setof text
as $$
declare 
    txtset text;
begin
    for txtset in (
        select distinct s.code
        from subjects s 
            join subject_prereqs sp on s.id = sp.subject
            join rules r on sp.rule = r.id
            join acad_object_groups a on r.ao_group = a.id
        where a.definition ~ Q10.code
    ) loop 
        return next txtset;
    end loop;
end;
$$ language plpgsql;
