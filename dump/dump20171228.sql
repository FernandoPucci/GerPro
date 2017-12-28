--
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Drop databases
--

--DROP DATABASE gerpro_dev;




--
-- Drop roles
--

--DROP ROLE postgres;


--
-- Roles
--

--CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS PASSWORD 'md5a3556571e93b0d20722ba62be61e8c2d';
ALTER ROLE postgres SET "TimeZone" TO '+03:00';






--
-- Database creation
--

CREATE DATABASE gerpro_dev WITH TEMPLATE = template0 OWNER = postgres CONNECTION LIMIT = 25;
REVOKE CONNECT,TEMPORARY ON DATABASE template1 FROM PUBLIC;
GRANT CONNECT ON DATABASE template1 TO PUBLIC;


\connect gerpro_dev

SET default_transaction_read_only = off;

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.4
-- Dumped by pg_dump version 9.6.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: before_update_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION before_update_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

BEGIN
    new.updated_at = now();
    RETURN new;        
END;

$$;


ALTER FUNCTION public.before_update_updated_at() OWNER TO postgres;

--
-- Name: clock_now(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION clock_now() RETURNS timestamp without time zone
    LANGUAGE plpgsql
    AS $$
  DECLARE
    clock_mocked_at TIMESTAMP;
  BEGIN
    SELECT INTO clock_mocked_at key_value::TIMESTAMP FROM parameters WHERE category_name = 'Tests' AND key_name = 'clock_mocked_at';
    IF clock_mocked_at ISNULL OR NOT (inet_server_addr()::TEXT LIKE '192.168%') THEN
      RETURN clock_timestamp();
    END IF;
    RETURN clock_mocked_at;
  END;
$$;


ALTER FUNCTION public.clock_now() OWNER TO postgres;

--
-- Name: execution_queue_delete_after_update_executed_sets_true(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION execution_queue_delete_after_update_executed_sets_true() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

BEGIN
    IF NEW.executed THEN
      DELETE FROM execution_queue WHERE id = NEW.id;
    END IF;
    RETURN new;        
END;

$$;


ALTER FUNCTION public.execution_queue_delete_after_update_executed_sets_true() OWNER TO postgres;

--
-- Name: execution_queue_to_json(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION execution_queue_to_json() RETURNS json
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RETURN execution_queue_to_json(false);
  END
$$;


ALTER FUNCTION public.execution_queue_to_json() OWNER TO postgres;

--
-- Name: execution_queue_to_json(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION execution_queue_to_json(humanized boolean) RETURNS json
    LANGUAGE plpgsql
    AS $$
  DECLARE
    execution_queue_json JSON;
    notifications_json JSON;

  BEGIN
    -- Funcoes row_to_json usada para converter uma tupla inteira para JSON,
    -- array_agg para fazer agregacao de varias tuplas numa soh e
    -- array_to_json que converte o resultado de tudo isso para JSON
    -- sao as que fazem o milagre
    SELECT INTO execution_queue_json array_to_json(array_agg(row_to_json(eqj, humanized))) AS execution_queue
      FROM ( SELECT eq.id, eq.task_check_id, eq.next_execution,
                    tc.name AS task_check_name, tc.description AS task_check_description, pl.name AS place_name, us.name, us.email, us.mobile_message,
                    ( SELECT array_to_json(array_agg(row_to_json(nj, humanized))) AS notifications
                        FROM ( SELECT ns.notification_type_id, pm.key_name AS notifications_type_name
                               FROM notifications ns
                                 INNER JOIN parameters pm ON ns.notification_type_id = pm.id
                                 INNER JOIN task_checks tc ON ns.task_check_id = tc.id
                               WHERE tc.id = eq.task_check_id
                             ) nj
                    ) AS notifications 

             FROM execution_queue eq
               INNER JOIN task_checks tc ON eq.task_check_id = tc.id
               INNER JOIN places pl ON tc.place_id = pl.id
               INNER JOIN users us ON tc.user_checker_id = us.id
           ) eqj;

    RETURN execution_queue_json;
  END
$$;


ALTER FUNCTION public.execution_queue_to_json(humanized boolean) OWNER TO postgres;

--
-- Name: execution_queue_to_json(boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION execution_queue_to_json(humanized boolean, text_json boolean) RETURNS text
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RETURN execution_queue_to_json(humanized)::TEXT;
  END
$$;


ALTER FUNCTION public.execution_queue_to_json(humanized boolean, text_json boolean) OWNER TO postgres;

--
-- Name: insert_into_execution_queue(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue() RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
    ts_inserted INTEGER;             -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao

  BEGIN
    ts_inserted = 0;

    ts_inserted = ts_inserted + ( insert_into_execution_queue_one_time() );
    ts_inserted = ts_inserted + ( insert_into_execution_queue_daily() );
    ts_inserted = ts_inserted + ( insert_into_execution_queue_weekly() );
    ts_inserted = ts_inserted + ( insert_into_execution_queue_monthly() );
    ts_inserted = ts_inserted + ( insert_into_execution_queue_yearly() );

    RETURN ts_inserted;  -- Quantidades de linhas inseridas na tabela execution_queue
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue() OWNER TO postgres;

--
-- Name: insert_into_execution_queue_daily(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue_daily() RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
    task_check_to_insert RECORD;  -- Usada no loop FOR para inserir na tabela execution_queue
    inserted INTEGER;             -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao
    moment TIMESTAMP;             -- Momento atual + 5 minutos que eh o momento para a proxima execucao
    today DATE;                   -- Data do momento atual

  BEGIN
    moment = date_trunc('minute', clock_now()) + interval '5 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    today = moment::DATE;

    inserted = 0;

    FOR task_check_to_insert IN
    SELECT tc.id, 
           --- dt.hour || ':' || dt.minute AS horario,
           --- ns.notification_type_id,
  
           --- ns.pre_notify_days, ns.pre_notify_hours, ns.pre_notify_minutes, tc.repeats_every,

           -- Periodicidade value e name
           --- pm.key_value AS periodicity_key_value, pm.key_name AS periodicity_key_name,

           -- Inicio de todas as notificacoes
           --- tc.starts_at + (SELECT min(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) - ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') AS inicio_de_todas_as_notificacoes,

           -- Fim de todas as notificacoes
           --- tc.ends_at + (SELECT max(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) AS fim_de_todas_as_notificacoes,

           -- Momento de iniciar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
           --- today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) AS momento_de_iniciar_notiicacao,

           -- Momento de finalizar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
           --- today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) ) * interval '1 minute' ) AS momento_de_finalizar_notiicacao,

           -- Minutos passados desde o inicio das notificacoes
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER AS minutos_passados_desde_o_inicio_das_notificacoes,
       
           -- Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           --- AS minutos_passados_desde_o_inicio_das_notificacoes_a_cada_5_min,
       
           -- Notificar Agora
           --(Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos) % (repetir a cada x minutos) = 0
           --- ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           ---  (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
           ---  ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           ---  (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           --- ) % greatest(1, ns.notify_again_every) = 0
           --- AS notificar_agora,

           -- Dias do mes em que ocorrera a verificacao da tarefa
           --- date_part('DAY', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'),

           -- Dentro da periodicidade?
           --( SELECT count(*) - 1 FROM generate_series(tc.starts_at, moment + ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'), '1 day' ) ) AS dias_desde_a_primeira_notificacao,  -- Está no dia de notificar (considerando os dias para comecar a notificar)

           -- Proxima notificacao em YYYY-MM-DD hh:mm:ss
           -- Momento de iniciar a notificacao +
           ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' )
           ) +
           -- Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos
           ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
             ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           ) * interval '1 minute'
           AS next_execution
       
      FROM task_checks tc 
        INNER JOIN days_times dt ON tc.id = dt.task_check_id
        INNER JOIN notifications ns ON tc.id = ns.task_check_id
        INNER JOIN parameters pm ON tc.periodicity_id = pm.id

      WHERE tc.active AND
 
            -- Periodicidade DIARIO
            pm.category_name = 'periodicidades' AND pm.key_name = 'diario' AND
 
            -- Inicio de todas as notificacoes eh menor que o momento atual
            tc.starts_at + (SELECT min(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) - ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') <= moment AND    -- Inicia antes de hoje ou hoje (considerando os dias, horas e minutos para comecar a notificar)

            -- Fim de todas as notificacoes eh maior que o momento atual
	    ( tc.ends_at ISNULL OR tc.ends_at + (SELECT max(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) >= moment ) AND    -- Nao finaliza hoje (ou depois considerando dias horas e minutos para notificar)

            -- Momento de iniciar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
            -- eh menor ou igual que a hora atual? (ja iniciou o periodo de notificacao)
            today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
            (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) <= moment AND

            -- Momento de finalizar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
            -- eh maior ou igual que a hora atual? (ainda nao terminou o periodo de notificacao)
            today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
            (dt.hour*60 + dt.minute) ) * interval '1 minute' ) >= moment AND

            -- Notificar Agora? (Estah no momento de notificar a cada x minutos?)
            --(Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos) % (repetir a cada x minutos) = 0
            ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
              (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
              ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
              (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
            ) % greatest(1, ns.notify_again_every) = 0 AND

            -- Dentro da periodicidade?
            ( SELECT count(*) - 1 FROM generate_series(tc.starts_at, moment + ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'), '1 day' ) ) % greatest(1,tc.repeats_every) = 0  -- Está no dia de notificar (considerando os dias para comecar a notificar)

    LOOP
      IF ( SELECT count(*) FROM execution_queue WHERE task_check_id = task_check_to_insert.id AND next_execution = task_check_to_insert.next_execution ) = 0 THEN
        -- Nao existe na fila de execucao ainda entao INSERE
        INSERT INTO execution_queue (task_check_id, next_execution) VALUES (task_check_to_insert.id, task_check_to_insert.next_execution);
        inserted = inserted + 1;
      END IF;
    END LOOP;

    RETURN inserted;  -- Quantidades de linhas inseridas na tabela execution_queue
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue_daily() OWNER TO postgres;

--
-- Name: insert_into_execution_queue_daily_test(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue_daily_test() RETURNS TABLE(function_name character varying, test_passed boolean, details text, running_time interval)
    LANGUAGE plpgsql
    AS $$
  DECLARE
    place_id_test INTEGER;                -- id do local para usar nos testes
    periodicity_id_test INTEGER;          -- id da periodicidade usada nos testes
    date_test DATE;                       -- Data para o teste
    days_time_hour_to_test INTEGER[2];    -- Hora para o Teste
    days_time_minute_to_test INTEGER[2];  -- Minuto para o Teste
    task_check_id_test INTEGER[2];        -- array com os id da verificacao de tarefa que serah testada
    tc_id INTEGER;                        -- id que será armazenado em task_check_id_test

    start_time_test TIMESTAMP;            -- Momento de inicio do teste
    end_time_test   TIMESTAMP;            -- Momento de fim do teste

    task_check_test TEXT;                 -- String JSON com a tarefa a ser inserida e testada

    moment TIMESTAMP;                     -- Momento atual + 5 ou 10 minutos que eh o momento para a proxima execucao (arredondado de 5 em 5 minutos)

    inserteds INTEGER[2];                 -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao
    inserted INTEGER;                     -- Serah armazenado no array inserteds


  BEGIN
    
    PERFORM set_clock_now('2017-08-27T16:55:00');  -- Faz mock do relogio
    start_time_test := clock_now();

    INSERT INTO places (company_id, name, updated_by_user_id) VALUES (1, 'Local apenas para testes das funcoes do banco de dados', 1) RETURNING id INTO place_id_test;
    SELECT INTO periodicity_id_test id FROM parameters WHERE category_name = 'periodicidades' AND key_name = 'diario';

--     RAISE NOTICE 'place_id_test = %', place_id_test;
--     RAISE NOTICE 'periodicity_id_test = %', periodicity_id_test;

    date_test := clock_now()::DATE;
    moment := date_trunc('minute', clock_now()) + interval '5 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    days_time_hour_to_test[1] := date_part('hour', moment)::INTEGER;
    days_time_minute_to_test[1] := date_part('minute', moment)::INTEGER;

--     RAISE NOTICE 'date_test = %, days_time_hour_to_test = %, days_time_minute_to_test = %', date_test, days_time_hour_to_test, days_time_minute_to_test;

    task_check_test :=
      '{ "name": "Teste 1 - SEM ANTECEDECIA E SEM RENOTIFICACAO",
         "description": "Teste de tarefa diaria 1.",
         "place_id": ' || place_id_test || ',
         "user_checker_id": 2,
         "periodicity_id": ' || periodicity_id_test || ',
         "starts_at": "' || date_test || '",
         "ends_at": null,
         "repeats_every": 1,
         "updated_by_user_id": 1,
         "days_times": [ { "hour": ' || days_time_hour_to_test[1] || ', "minute": ' || days_time_minute_to_test[1] || ' } ],
         "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 0, "pre_notify_minutes": 0, "notify_again_every": 0 } ]
       }';

    RAISE NOTICE 'task_check_test = %', task_check_test;

    SELECT INTO tc_id insert_taskcheckjson(task_check_test);
    task_check_id_test[1] := tc_id;

    moment := date_trunc('minute', clock_now()) + interval '15 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    days_time_hour_to_test[2] := date_part('hour', moment)::INTEGER;
    days_time_minute_to_test[2] := date_part('minute', moment)::INTEGER;

    task_check_test :=
      '{ "name": "Teste 2 - COM ANTECEDECIA E COM RENOTIFICACAO",
         "description": "Teste de tarefa diaria 2.",
         "place_id": ' || place_id_test || ',
         "user_checker_id": 2,
         "periodicity_id": ' || periodicity_id_test || ',
         "starts_at": "' || date_test || '",
         "ends_at": null,
         "repeats_every": 1,
         "updated_by_user_id": 1,
         "days_times": [ { "hour": ' || days_time_hour_to_test[2] || ', "minute": ' || days_time_minute_to_test[2] || ' } ],
         "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 0, "pre_notify_minutes": 10, "notify_again_every": 5 } ]
       }';

    RAISE NOTICE 'task_check_test = %', task_check_test;

    SELECT INTO tc_id insert_taskcheckjson(task_check_test);
    task_check_id_test[2] := tc_id;

    
--     RAISE NOTICE 'task_check_id_test = %', task_check_id_test;

    --PERFORM set_clock_now('2017-08-27T16:55:01');  -- Faz mock do relogio ou PERFORM pg_sleep(1);

    PERFORM set_clock_now('2017-08-27T16:55:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);
    PERFORM insert_into_execution_queue_daily();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir de 10 minutos antes...', 5;

    PERFORM set_clock_now('2017-08-27T17:00:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_daily();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir de 5 minutos antes...', 5;

    PERFORM set_clock_now('2017-08-27T17:05:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_daily();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir do momento da ultima notificacao...', 5;

    PERFORM set_clock_now('2017-08-27T17:10:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_daily();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    PERFORM set_clock_now('2017-08-27T17:15:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_daily();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    DELETE FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    DELETE FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    DELETE FROM task_checks WHERE id = task_check_id_test[1];
    DELETE FROM task_checks WHERE id = task_check_id_test[2];
    DELETE FROM places WHERE id = place_id_test;

    RAISE NOTICE 'clock_now(): %', clock_now();
    end_time_test := clock_now();

    PERFORM set_clock_now(NULL);  -- Desfaz mock do relogio

    RETURN QUERY
    (
      SELECT t.function_name, t.test_passed, t.details, t.running_time 
        FROM ( SELECT 'insert_into_execution_queue_daily()'::VARCHAR(64) AS function_name,
                      (inserteds[1] = 1 AND inserteds[2] = 3) AS test_passed,
                      ('Esperados: inserteds[1] = 1, inserteds[2] = 3' || E'\n' || 'Retornados: inserteds[1] = ' || inserteds[1] || ', inserteds[2] = ' || inserteds[2] )::TEXT AS details,
                      end_time_test - start_time_test AS running_time
             ) t
    );
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue_daily_test() OWNER TO postgres;

--
-- Name: insert_into_execution_queue_monthly(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue_monthly() RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
    task_check_to_insert RECORD;  -- Usada no loop FOR para inserir na tabela execution_queue
    inserted INTEGER;             -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao
    moment TIMESTAMP;             -- Momento atual + 5 minutos que eh o momento para a proxima execucao
    today DATE;                   -- Data do momento atual

  BEGIN
    moment = date_trunc('minute', clock_now()) + interval '5 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    today = moment::DATE;

    inserted = 0;

    FOR task_check_to_insert IN
    SELECT tc.id, 
           --- dt.hour || ':' || dt.minute AS horario,
           --- ns.notification_type_id,
  
           --- ns.pre_notify_days, ns.pre_notify_hours, ns.pre_notify_minutes, tc.repeats_every,

           -- Periodicidade value e name
           --- pm.key_value AS periodicity_key_value, pm.key_name AS periodicity_key_name,

           -- Meses desde que comecou
           --- ( SELECT count(*) - 1 FROM generate_series(tc.starts_at, moment + ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'), '1 month' ) ) AS months_from_starts_at,

           -- Inicio de todas as notificacoes
           --- tc.starts_at + (SELECT min(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) - ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') AS inicio_de_todas_as_notificacoes,
 
           -- Fim de todas as notificacoes
           --- tc.ends_at + (SELECT max(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) AS fim_de_todas_as_notificacoes,

           -- Momento de iniciar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
           --- today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) AS momento_de_iniciar_notiicacao,

           -- Momento de finalizar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
           --- today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) ) * interval '1 minute' ) AS momento_de_finalizar_notiicacao,

           -- Minutos passados desde o inicio das notificacoes
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER AS minutos_passados_desde_o_inicio_das_notificacoes,
       
           -- Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           --- AS minutos_passados_desde_o_inicio_das_notificacoes_a_cada_5_min,
       
           -- Notificar Agora
           --(Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos) % (repetir a cada x minutos) = 0
           --- ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           ---  (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
           ---  ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           ---  (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           --- ) % greatest(1, ns.notify_again_every) = 0
           --- AS notificar_agora,

           -- Dias do mes em que ocorrera a verificacao da tarefa
           --- date_part('DAY', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'),

           -- Proxima notificacao em YYYY-MM-DD hh:mm:ss
           -- Momento de iniciar a notificacao +
           ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' )
           ) +
           -- Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos
           ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
             ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           ) * interval '1 minute'
           AS next_execution
       
      FROM task_checks tc 
        INNER JOIN months_days md ON tc.id = md.task_check_id
        INNER JOIN days_times dt ON tc.id = dt.task_check_id
        INNER JOIN notifications ns ON tc.id = ns.task_check_id
        INNER JOIN parameters pm ON tc.periodicity_id = pm.id

      WHERE tc.active AND

            -- Periodicidade DIARIO
            pm.category_name = 'periodicidades' AND pm.key_name = 'mensal' AND

            -- Inicio de todas as notificacoes eh menor que o momento atual
            tc.starts_at + (SELECT min(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) - ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') <= moment AND    -- Inicia antes de hoje ou hoje (considerando os dias, horas e minutos para comecar a notificar)
 
            -- Fim de todas as notificacoes eh maior que o momento atual
            ( tc.ends_at ISNULL OR tc.ends_at + (SELECT max(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) >= moment ) AND    -- Nao finaliza hoje (ou depois considerando dias horas e minutos para notificar)

            -- Momento de iniciar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
            -- eh menor ou igual que a hora atual? (ja iniciou o periodo de notificacao)
            today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
            (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) <= moment AND
 
            -- Momento de finalizar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
            -- eh maior ou igual que a hora atual? (ainda nao terminou o periodo de notificacao)
            today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
            (dt.hour*60 + dt.minute) ) * interval '1 minute' ) >= moment AND

            -- Notificar Agora? (Estah no momento de notificar a cada x minutos?)
            --(Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos) % (repetir a cada x minutos) = 0
            ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
              (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
              ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
              (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
            ) % greatest(1, ns.notify_again_every) = 0 AND

            -- Dias do mes em que ocorrera a verificacao da tarefa
            md.month_day = date_part('DAY', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') AND   -- Hoje eh dia de notificar (considerando os dias para comecar a notificar)
  
            -- Dentro da periodicidade?
            ( SELECT count(*) - 1 FROM generate_series(tc.starts_at, moment + ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'), '1 month' ) ) % greatest(1,tc.repeats_every) = 0  -- Está no mês de notificar (considerando os dias para comecar a notificar)

    LOOP
      IF ( SELECT count(*) FROM execution_queue WHERE task_check_id = task_check_to_insert.id AND next_execution = task_check_to_insert.next_execution ) = 0 THEN
        -- Nao existe na fila de execucao ainda entao INSERE
        INSERT INTO execution_queue (task_check_id, next_execution) VALUES (task_check_to_insert.id, task_check_to_insert.next_execution);
        inserted = inserted + 1;
      END IF;
    END LOOP;

    RETURN inserted;  -- Quantidades de linhas inseridas na tabela execution_queue
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue_monthly() OWNER TO postgres;

--
-- Name: insert_into_execution_queue_monthly_test(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue_monthly_test() RETURNS TABLE(function_name character varying, test_passed boolean, details text, running_time interval)
    LANGUAGE plpgsql
    AS $$
  DECLARE
    place_id_test INTEGER;                -- id do local para usar nos testes
    periodicity_id_test INTEGER;          -- id da periodicidade usada nos testes
    date_test DATE;                       -- Data para o teste
    days_time_hour_to_test INTEGER[2];    -- Hora para o Teste
    days_time_minute_to_test INTEGER[2];  -- Minuto para o Teste
    task_check_id_test INTEGER[2];        -- array com os id da verificacao de tarefa que serah testada
    tc_id INTEGER;                        -- id que será armazenado em task_check_id_test

    start_time_test TIMESTAMP;            -- Momento de inicio do teste
    end_time_test   TIMESTAMP;            -- Momento de fim do teste

    task_check_test TEXT;                 -- String JSON com a tarefa a ser inserida e testada

    moment TIMESTAMP;                     -- Momento atual + 5 ou 10 minutos que eh o momento para a proxima execucao (arredondado de 5 em 5 minutos)

    inserteds INTEGER[2];                 -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao
    inserted INTEGER;                     -- Serah armazenado no array inserteds


  BEGIN
    
    PERFORM set_clock_now('2017-08-28T16:55:00');  -- Faz mock do relogio
    start_time_test := clock_now();

    INSERT INTO places (company_id, name, updated_by_user_id) VALUES (1, 'Local apenas para testes das funcoes do banco de dados', 1) RETURNING id INTO place_id_test;
    SELECT INTO periodicity_id_test id FROM parameters WHERE category_name = 'periodicidades' AND key_name = 'mensal';

    RAISE NOTICE 'place_id_test = %', place_id_test;
    RAISE NOTICE 'periodicity_id_test = %', periodicity_id_test;

    date_test := clock_now()::DATE;
    moment := date_trunc('minute', clock_now()) + interval '5 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    days_time_hour_to_test[1] := date_part('hour', moment)::INTEGER;
    days_time_minute_to_test[1] := date_part('minute', moment)::INTEGER;

    RAISE NOTICE 'date_test = %, days_time_hour_to_test = %, days_time_minute_to_test = %', date_test, days_time_hour_to_test, days_time_minute_to_test;

    task_check_test :=
      '{ "name": "Teste 1 - SEM ANTECEDECIA E SEM RENOTIFICACAO",
         "description": "Teste de tarefa diaria 1.",
         "place_id": ' || place_id_test || ',
         "user_checker_id": 2,
         "periodicity_id": ' || periodicity_id_test || ',
         "starts_at": "' || date_test || '",
         "ends_at": null,
         "repeats_every": 1,
         "updated_by_user_id": 1,
         "days_times": [ { "hour": ' || days_time_hour_to_test[1] || ', "minute": ' || days_time_minute_to_test[1] || ' } ],
         "months_days": [ {"month_day": 28} ],
         "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 0, "pre_notify_minutes": 0, "notify_again_every": 0 } ]
       }';

    RAISE NOTICE 'task_check_test = %', task_check_test;

    SELECT INTO tc_id insert_taskcheckjson(task_check_test);
    task_check_id_test[1] := tc_id;

    moment := date_trunc('minute', clock_now()) + interval '15 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    days_time_hour_to_test[2] := date_part('hour', moment)::INTEGER;
    days_time_minute_to_test[2] := date_part('minute', moment)::INTEGER;

    task_check_test :=
      '{ "name": "Teste 2 - COM ANTECEDECIA E COM RENOTIFICACAO",
         "description": "Teste de tarefa diaria 2.",
         "place_id": ' || place_id_test || ',
         "user_checker_id": 2,
         "periodicity_id": ' || periodicity_id_test || ',
         "starts_at": "' || date_test || '",
         "ends_at": null,
         "repeats_every": 1,
         "updated_by_user_id": 1,
         "days_times": [ { "hour": ' || days_time_hour_to_test[2] || ', "minute": ' || days_time_minute_to_test[2] || ' } ],
         "months_days": [ {"month_day": 28} ],
         "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 0, "pre_notify_minutes": 10, "notify_again_every": 5 } ]
       }';

    RAISE NOTICE 'task_check_test = %', task_check_test;

    SELECT INTO tc_id insert_taskcheckjson(task_check_test);
    task_check_id_test[2] := tc_id;

    
--     RAISE NOTICE 'task_check_id_test = %', task_check_id_test;

    --PERFORM set_clock_now('2017-08-28T16:55:01');  -- Faz mock do relogio ou PERFORM pg_sleep(1);

    PERFORM set_clock_now('2017-08-28T16:55:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);
    PERFORM insert_into_execution_queue_monthly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir de 10 minutos antes...', 5;

    PERFORM set_clock_now('2017-08-28T17:00:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_monthly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir de 5 minutos antes...', 5;

    PERFORM set_clock_now('2017-08-28T17:05:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_monthly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir do momento da ultima notificacao...', 5;

    PERFORM set_clock_now('2017-08-28T17:10:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_monthly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    PERFORM set_clock_now('2017-08-28T17:15:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_monthly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    DELETE FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    DELETE FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    DELETE FROM task_checks WHERE id = task_check_id_test[1];
    DELETE FROM task_checks WHERE id = task_check_id_test[2];
    DELETE FROM places WHERE id = place_id_test;

    RAISE NOTICE 'clock_now(): %', clock_now();
    end_time_test := clock_now();

    PERFORM set_clock_now(NULL);  -- Desfaz mock do relogio

    RETURN QUERY
    (
      SELECT t.function_name, t.test_passed, t.details, t.running_time 
        FROM ( SELECT 'insert_into_execution_queue_monthly()'::VARCHAR(64) AS function_name,
                      (inserteds[1] = 1 AND inserteds[2] = 3) AS test_passed,
                      ('Esperados: inserteds[1] = 1, inserteds[2] = 3' || E'\n' || 'Retornados: inserteds[1] = ' || inserteds[1] || ', inserteds[2] = ' || inserteds[2] )::TEXT AS details,
                      end_time_test - start_time_test AS running_time
             ) t
    );
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue_monthly_test() OWNER TO postgres;

--
-- Name: insert_into_execution_queue_one_time(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue_one_time() RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
    task_check_to_insert RECORD;  -- Usada no loop FOR para inserir na tabela execution_queue
    inserted INTEGER;             -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao
    moment TIMESTAMP;             -- Momento atual + 5 minutos que eh o momento para a proxima execucao
    today DATE;                   -- Data do momento atual

  BEGIN
    moment := date_trunc('minute', clock_now()) + interval '5 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    today := moment::DATE;
  
    inserted := 0;

    FOR task_check_to_insert IN
    SELECT tc.id, 
           --- dt.hour || ':' || dt.minute AS horario,
           --- ns.notification_type_id,
    
           --- ns.pre_notify_days, ns.pre_notify_hours, ns.pre_notify_minutes, tc.repeats_every,

           -- Periodicidade value e name
           --- pm.key_value AS periodicity_key_value, pm.key_name AS periodicity_key_name,

           -- Inicio de todas as notificacoes
           --- tc.starts_at + (SELECT min(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) - ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') AS inicio_de_todas_as_notificacoes,

           -- Fim de todas as notificacoes
           --- tc.ends_at + (SELECT max(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) AS fim_de_todas_as_notificacoes,

           -- Momento de iniciar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
           --- today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) AS momento_de_iniciar_notiicacao,

           -- Momento de finalizar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
           --- today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) ) * interval '1 minute' ) AS momento_de_finalizar_notiicacao,

           -- Minutos passados desde o inicio das notificacoes
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER AS minutos_passados_desde_o_inicio_das_notificacoes,
       
           -- Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           --- AS minutos_passados_desde_o_inicio_das_notificacoes_a_cada_5_min,
       
           -- Notificar Agora
           --(Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos) % maior(1,repetir a cada x minutos) = 0
           --- ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           ---  (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
           ---  ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           ---  (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           --- ) % greatest(1,ns.notify_again_every) = 0
           --- AS notificar_agora,

           -- Dias do mes em que ocorrera a verificacao da tarefa
           --- date_part('DAY', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'),

           -- Proxima notificacao em YYYY-MM-DD hh:mm:ss
           -- Momento de iniciar a notificacao +
           ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' )
           ) +
           -- Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos
           ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
             ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           ) * interval '1 minute'
           AS next_execution
       
      FROM task_checks tc 
        INNER JOIN days_times dt ON tc.id = dt.task_check_id
        INNER JOIN notifications ns ON tc.id = ns.task_check_id
        INNER JOIN parameters pm ON tc.periodicity_id = pm.id

      WHERE tc.active AND
  
            -- Periodicidade unica_vez
            pm.category_name = 'periodicidades' AND pm.key_name = 'unica_vez' AND

            -- Inicio de todas as notificacoes eh menor que o momento atual
            tc.starts_at + (SELECT min(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) - ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') <= moment AND    -- Inicia antes de hoje ou hoje (considerando os dias, horas e minutos para comecar a notificar)

            -- Fim de todas as notificacoes eh maior que o momento atual
            ( tc.ends_at ISNULL OR tc.ends_at + (SELECT max(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) >= moment ) AND    -- Nao finaliza hoje (ou depois considerando dias horas e minutos para notificar)

            -- Momento de iniciar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
            -- eh menor ou igual que a hora atual? (ja iniciou o periodo de notificacao)
            today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
            (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) <= moment AND

            -- Momento de finalizar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
            -- eh maior ou igual que a hora atual? (ainda nao terminou o periodo de notificacao)
            today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
            (dt.hour*60 + dt.minute) ) * interval '1 minute' ) >= moment AND
 
            -- Notificar Agora? (Estah no momento de notificar a cada x minutos?)
            --(Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos) % maior(1,repetir a cada x minutos) = 0
            ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
              (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
              ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
              (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
            ) % greatest(1,ns.notify_again_every) = 0 AND
 
            -- Dentro da periodicidade?
            ( SELECT count(*) - 1 FROM generate_series(tc.starts_at, moment + ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'), '1 month' ) ) % greatest(1,tc.repeats_every) = 0  -- Está no mês de notificar (considerando os dias para comecar a notificar)

    LOOP
      IF ( SELECT count(*) FROM execution_queue WHERE task_check_id = task_check_to_insert.id AND next_execution = task_check_to_insert.next_execution ) = 0 THEN
        -- Nao existe na fila de execucao ainda entao INSERE
        INSERT INTO execution_queue (task_check_id, next_execution) VALUES (task_check_to_insert.id, task_check_to_insert.next_execution);
        inserted = inserted + 1;
      END IF;
    END LOOP;

    RETURN inserted;  -- Quantidades de linhas inseridas na tabela execution_queue
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue_one_time() OWNER TO postgres;

--
-- Name: insert_into_execution_queue_one_time_test(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue_one_time_test() RETURNS TABLE(function_name character varying, test_passed boolean, details text, running_time interval)
    LANGUAGE plpgsql
    AS $$
  DECLARE
    place_id_test INTEGER;       -- id do local para usar nos testes
    periodicity_id_test INTEGER; -- id da periodicidade usada nos testes
    date_test DATE;           -- Data para o teste
    days_time_hour_to_test INTEGER[2];        -- Hora para o Teste
    days_time_minute_to_test INTEGER[2];      -- Minuto para o Teste
    task_check_id_test INTEGER[2];  -- array com os id da verificacao de tarefa que serah testada
    tc_id INTEGER;  -- id que será armazenado em task_check_id_test

    start_time_test TIMESTAMP;  -- Momento de inicio do teste
    end_time_test   TIMESTAMP;  -- Momento de fim do teste

    task_check_test TEXT;         -- String JSON com a tarefa a ser inserida e testada

    moment TIMESTAMP;             -- Momento atual + 5 ou 10 minutos que eh o momento para a proxima execucao (arredondado de 5 em 5 minutos)

    inserteds INTEGER[2];             -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao
    inserted INTEGER;   -- Serah armazenado no array inserteds


  BEGIN
    
    PERFORM set_clock_now('2017-08-27T16:55:00');  -- Faz mock do relogio
    start_time_test := clock_now();

    INSERT INTO places (company_id, name, updated_by_user_id) VALUES (1, 'Local apenas para testes das funcoes do banco de dados', 1) RETURNING id INTO place_id_test;
    SELECT INTO periodicity_id_test id FROM parameters WHERE category_name = 'periodicidades' AND key_name = 'unica_vez';

--     RAISE NOTICE 'place_id_test = %', place_id_test;
--     RAISE NOTICE 'periodicity_id_test = %', periodicity_id_test;

    date_test := clock_now()::DATE;
    moment := date_trunc('minute', clock_now()) + interval '5 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    days_time_hour_to_test[1] := date_part('hour', moment)::INTEGER;
    days_time_minute_to_test[1] := date_part('minute', moment)::INTEGER;

--     RAISE NOTICE 'date_test = %, days_time_hour_to_test = %, days_time_minute_to_test = %', date_test, days_time_hour_to_test, days_time_minute_to_test;

    task_check_test :=
      '{ "name": "Teste 1 - SEM ANTECEDECIA E SEM RENOTIFICACAO",
         "description": "Teste de tarefa unica 1 que serah inserida na fila uma unica vez.",
         "place_id": ' || place_id_test || ',
         "user_checker_id": 2,
         "periodicity_id": ' || periodicity_id_test || ',
         "starts_at": "' || date_test || '",
         "ends_at": null,
         "repeats_every": 1,
         "updated_by_user_id": 1,
         "days_times": [ { "hour": ' || days_time_hour_to_test[1] || ', "minute": ' || days_time_minute_to_test[1] || ' } ],
         "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 0, "pre_notify_minutes": 0, "notify_again_every": 0 } ]
       }';

--     RAISE NOTICE 'task_check_test = %', task_check_test;

    SELECT INTO tc_id insert_taskcheckjson(task_check_test);
    task_check_id_test[1] := tc_id;

    moment := date_trunc('minute', clock_now()) + interval '15 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    days_time_hour_to_test[2] := date_part('hour', moment)::INTEGER;
    days_time_minute_to_test[2] := date_part('minute', moment)::INTEGER;

    task_check_test :=
      '{ "name": "Teste 2 - COM ANTECEDECIA E COM RENOTIFICACAO",
         "description": "Teste de tarefa unica 2 que serah inserida na fila uma unica vez.",
         "place_id": ' || place_id_test || ',
         "user_checker_id": 2,
         "periodicity_id": ' || periodicity_id_test || ',
         "starts_at": "' || date_test || '",
         "ends_at": null,
         "repeats_every": 1,
         "updated_by_user_id": 1,
         "days_times": [ { "hour": ' || days_time_hour_to_test[2] || ', "minute": ' || days_time_minute_to_test[2] || ' } ],
         "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 0, "pre_notify_minutes": 10, "notify_again_every": 5 } ]
       }';

    RAISE NOTICE 'task_check_test = %', task_check_test;

    SELECT INTO tc_id insert_taskcheckjson(task_check_test);
    task_check_id_test[2] := tc_id;

    
--     RAISE NOTICE 'task_check_id_test = %', task_check_id_test;

    --PERFORM set_clock_now('2017-08-27T16:55:01');  -- Faz mock do relogio ou PERFORM pg_sleep(1);

    PERFORM set_clock_now('2017-08-27T16:55:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);
    PERFORM insert_into_execution_queue_one_time();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir de 10 minutos antes...', 5;

    PERFORM set_clock_now('2017-08-27T17:00:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_one_time();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir de 5 minutos antes...', 5;

    PERFORM set_clock_now('2017-08-27T17:05:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_one_time();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir do momento da ultima notificacao...', 5;

    PERFORM set_clock_now('2017-08-27T17:10:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_one_time();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    PERFORM set_clock_now('2017-08-27T17:15:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_one_time();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    DELETE FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    DELETE FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    DELETE FROM task_checks WHERE id = task_check_id_test[1];
    DELETE FROM task_checks WHERE id = task_check_id_test[2];
    DELETE FROM places WHERE id = place_id_test;

    RAISE NOTICE 'clock_now(): %', clock_now();
    end_time_test := clock_now();

    PERFORM set_clock_now(NULL);  -- Desfaz mock do relogio

    RETURN QUERY
    (
      SELECT t.function_name, t.test_passed, t.details, t.running_time 
        FROM ( SELECT 'insert_into_execution_queue_one_time()'::VARCHAR(64) AS function_name,
                      (inserteds[1] = 1 AND inserteds[2] = 3) AS test_passed,
                      ('Esperados: inserteds[1] = 1, inserteds[2] = 3' || E'\n' || 'Retornados: inserteds[1] = ' || inserteds[1] || ', inserteds[2] = ' || inserteds[2] )::TEXT AS details,
                      end_time_test - start_time_test AS running_time
             ) t
    );
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue_one_time_test() OWNER TO postgres;

--
-- Name: insert_into_execution_queue_weekly(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue_weekly() RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
    task_check_to_insert RECORD;  -- Usada no loop FOR para inserir na tabela execution_queue
    inserted INTEGER;             -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao
    moment TIMESTAMP;             -- Momento atual + 5 minutos que eh o momento para a proxima execucao
    today DATE;                   -- Data do momento atual

  BEGIN
    moment = date_trunc('minute', clock_now()) + interval '5 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    today = moment::DATE;

    inserted = 0;

    FOR task_check_to_insert IN
    SELECT tc.id, 
           --- dt.hour || ':' || dt.minute AS horario,
           --- ns.notification_type_id,
    
           --- ns.pre_notify_days, ns.pre_notify_hours, ns.pre_notify_minutes, tc.repeats_every,

           -- Inicio de todas as notificacoes
           --- tc.starts_at + (SELECT min(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) - ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') AS inicio_de_todas_as_notificacoes,

           -- Fim de todas as notificacoes
           --- tc.ends_at + (SELECT max(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) AS fim_de_todas_as_notificacoes,

           -- Momento de iniciar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
           --- today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) AS momento_de_iniciar_notiicacao,

           -- Momento de finalizar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
           --- today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) ) * interval '1 minute' ) AS momento_de_finalizar_notiicacao,

           -- Minutos passados desde o inicio das notificacoes
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER AS minutos_passados_desde_o_inicio_das_notificacoes,
       
           -- Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           --- AS minutos_passados_desde_o_inicio_das_notificacoes_a_cada_5_min,
       
           -- Notificar Agora
           --(Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos) % (repetir a cada x minutos) = 0
           --- ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           ---  (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
           ---  ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           ---  (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           --- ) % greatest(1, ns.notify_again_every) = 0
           --- AS notificar_agora,
       
           -- Proxima notificacao em YYYY-MM-DD hh:mm:ss
           -- Momento de iniciar a notificacao +
           ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' )
           ) +
           -- Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos
           ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
             ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           ) * interval '1 minute'
           AS next_execution

           -- Semanas desde que comecou
           -- , ( SELECT count(*) - 1 FROM generate_series(tc.starts_at, moment + ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'), '1 week' ) ) AS semanas   -- Está na semana de notificar (considerando os dias para comecar a notificar)
       
      FROM task_checks tc 
        INNER JOIN weeks_days wd    ON tc.id = wd.task_check_id
        INNER JOIN days_times dt    ON tc.id = dt.task_check_id
        INNER JOIN notifications ns ON tc.id = ns.task_check_id
        INNER JOIN parameters pm    ON tc.periodicity_id = pm.id

      WHERE tc.active AND

            -- Periodicidade SEMANAL
            pm.category_name = 'periodicidades' AND pm.key_name = 'semanal' AND
 
            -- Inicio de todas as notificacoes eh menor que o momento atual
            tc.starts_at + (SELECT min(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) - ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') <= moment AND    -- Inicia antes de hoje ou hoje (considerando os dias, horas e minutos para comecar a notificar)

            -- Fim de todas as notificacoes eh maior que o momento atual
	    ( tc.ends_at ISNULL OR tc.ends_at + (SELECT max(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) >= moment ) AND    -- Nao finaliza hoje (ou depois considerando dias horas e minutos para notificar)

            -- Momento de iniciar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
            -- eh menor ou igual que a hora atual? (ja iniciou o periodo de notificacao)
            today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
            (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) <= moment AND

            -- Momento de finalizar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
            -- eh maior ou igual que a hora atual? (ainda nao terminou o periodo de notificacao)
            today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
            (dt.hour*60 + dt.minute) ) * interval '1 minute' ) >= moment AND

            -- Notificar Agora? (Estah no momento de notificar a cada x minutos?)
            --(Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos) % (repetir a cada x minutos) = 0
            ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
              (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
              ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
              (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
            ) % greatest(1, ns.notify_again_every) = 0 AND

            -- Dias da semana em que ocorrera a verificacao da tarefa
            ( (wd.sunday    AND date_part('DOW', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') = 0) OR   -- Hoje eh domingo, pede cachimbo, e estah marcado para execucao aos domingos (considerando os dias para comecar a notificar)
              (wd.monday    AND date_part('DOW', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') = 1) OR   -- idem segunda
              (wd.tuesday   AND date_part('DOW', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') = 2) OR   -- idem terca
              (wd.wednesday AND date_part('DOW', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') = 3) OR   -- idem quarta
              (wd.thursday  AND date_part('DOW', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') = 4) OR   -- idem quimta
              (wd.friday    AND date_part('DOW', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') = 5) OR   -- idem sexta
              (wd.saturday  AND date_part('DOW', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') = 6)      -- idem sabado
            ) AND

            -- Dentro da periodicidade?
            ( SELECT count(*) - 1 FROM generate_series(tc.starts_at, moment + ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'), '1 week' ) ) % greatest(1,tc.repeats_every) = 0  -- Está na semana de notificar (considerando os dias para comecar a notificar)
 
    LOOP
      IF ( SELECT count(*) FROM execution_queue WHERE task_check_id = task_check_to_insert.id AND next_execution = task_check_to_insert.next_execution ) = 0 THEN
        -- Nao existe na fila de execucao ainda entao INSERE
        INSERT INTO execution_queue (task_check_id, next_execution) VALUES (task_check_to_insert.id, task_check_to_insert.next_execution);
        inserted = inserted + 1;
      END IF;
    END LOOP;

    RETURN inserted;  -- Quantidades de linhas inseridas na tabela execution_queue
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue_weekly() OWNER TO postgres;

--
-- Name: insert_into_execution_queue_weekly_test(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue_weekly_test() RETURNS TABLE(function_name character varying, test_passed boolean, details text, running_time interval)
    LANGUAGE plpgsql
    AS $$
  DECLARE
    place_id_test INTEGER;                -- id do local para usar nos testes
    periodicity_id_test INTEGER;          -- id da periodicidade usada nos testes
    date_test DATE;                       -- Data para o teste
    days_time_hour_to_test INTEGER[2];    -- Hora para o Teste
    days_time_minute_to_test INTEGER[2];  -- Minuto para o Teste
    task_check_id_test INTEGER[2];        -- array com os id da verificacao de tarefa que serah testada
    tc_id INTEGER;                        -- id que será armazenado em task_check_id_test

    start_time_test TIMESTAMP;            -- Momento de inicio do teste
    end_time_test   TIMESTAMP;            -- Momento de fim do teste

    task_check_test TEXT;                 -- String JSON com a tarefa a ser inserida e testada

    moment TIMESTAMP;                     -- Momento atual + 5 ou 10 minutos que eh o momento para a proxima execucao (arredondado de 5 em 5 minutos)

    inserteds INTEGER[2];                 -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao
    inserted INTEGER;                     -- Serah armazenado no array inserteds


  BEGIN
    
    PERFORM set_clock_now('2017-08-28T16:55:00');  -- Faz mock do relogio
    start_time_test := clock_now();

    INSERT INTO places (company_id, name, updated_by_user_id) VALUES (1, 'Local apenas para testes das funcoes do banco de dados', 1) RETURNING id INTO place_id_test;
    SELECT INTO periodicity_id_test id FROM parameters WHERE category_name = 'periodicidades' AND key_name = 'semanal';

    RAISE NOTICE 'place_id_test = %', place_id_test;
    RAISE NOTICE 'periodicity_id_test = %', periodicity_id_test;

    date_test := clock_now()::DATE;
    moment := date_trunc('minute', clock_now()) + interval '5 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    days_time_hour_to_test[1] := date_part('hour', moment)::INTEGER;
    days_time_minute_to_test[1] := date_part('minute', moment)::INTEGER;

    RAISE NOTICE 'date_test = %, days_time_hour_to_test = %, days_time_minute_to_test = %', date_test, days_time_hour_to_test, days_time_minute_to_test;

    task_check_test :=
      '{ "name": "Teste 1 - SEM ANTECEDECIA E SEM RENOTIFICACAO",
         "description": "Teste de tarefa diaria 1.",
         "place_id": ' || place_id_test || ',
         "user_checker_id": 2,
         "periodicity_id": ' || periodicity_id_test || ',
         "starts_at": "' || date_test || '",
         "ends_at": null,
         "repeats_every": 1,
         "updated_by_user_id": 1,
         "days_times": [ { "hour": ' || days_time_hour_to_test[1] || ', "minute": ' || days_time_minute_to_test[1] || ' } ],
         "weeks_days": { "sunday": false, "monday": true, "tuesday": true, "wednesday": true, "thursday": true, "friday": true, "saturday": false },
         "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 0, "pre_notify_minutes": 0, "notify_again_every": 0 } ]
       }';

    RAISE NOTICE 'task_check_test = %', task_check_test;

    SELECT INTO tc_id insert_taskcheckjson(task_check_test);
    task_check_id_test[1] := tc_id;

    moment := date_trunc('minute', clock_now()) + interval '15 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    days_time_hour_to_test[2] := date_part('hour', moment)::INTEGER;
    days_time_minute_to_test[2] := date_part('minute', moment)::INTEGER;

    task_check_test :=
      '{ "name": "Teste 2 - COM ANTECEDECIA E COM RENOTIFICACAO",
         "description": "Teste de tarefa diaria 2.",
         "place_id": ' || place_id_test || ',
         "user_checker_id": 2,
         "periodicity_id": ' || periodicity_id_test || ',
         "starts_at": "' || date_test || '",
         "ends_at": null,
         "repeats_every": 1,
         "updated_by_user_id": 1,
         "days_times": [ { "hour": ' || days_time_hour_to_test[2] || ', "minute": ' || days_time_minute_to_test[2] || ' } ],
         "weeks_days": { "sunday": false, "monday": true, "tuesday": true, "wednesday": true, "thursday": true, "friday": true, "saturday": false },
         "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 0, "pre_notify_minutes": 10, "notify_again_every": 5 } ]
       }';

    RAISE NOTICE 'task_check_test = %', task_check_test;

    SELECT INTO tc_id insert_taskcheckjson(task_check_test);
    task_check_id_test[2] := tc_id;

    
--     RAISE NOTICE 'task_check_id_test = %', task_check_id_test;

    --PERFORM set_clock_now('2017-08-28T16:55:01');  -- Faz mock do relogio ou PERFORM pg_sleep(1);

    PERFORM set_clock_now('2017-08-28T16:55:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);
    PERFORM insert_into_execution_queue_weekly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir de 10 minutos antes...', 5;

    PERFORM set_clock_now('2017-08-28T17:00:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_weekly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir de 5 minutos antes...', 5;

    PERFORM set_clock_now('2017-08-28T17:05:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_weekly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir do momento da ultima notificacao...', 5;

    PERFORM set_clock_now('2017-08-28T17:10:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_weekly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    PERFORM set_clock_now('2017-08-28T17:15:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_weekly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    DELETE FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    DELETE FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    DELETE FROM task_checks WHERE id = task_check_id_test[1];
    DELETE FROM task_checks WHERE id = task_check_id_test[2];
    DELETE FROM places WHERE id = place_id_test;

    RAISE NOTICE 'clock_now(): %', clock_now();
    end_time_test := clock_now();

    PERFORM set_clock_now(NULL);  -- Desfaz mock do relogio

    RETURN QUERY
    (
      SELECT t.function_name, t.test_passed, t.details, t.running_time 
        FROM ( SELECT 'insert_into_execution_queue_weekly()'::VARCHAR(64) AS function_name,
                      (inserteds[1] = 1 AND inserteds[2] = 3) AS test_passed,
                      ('Esperados: inserteds[1] = 1, inserteds[2] = 3' || E'\n' || 'Retornados: inserteds[1] = ' || inserteds[1] || ', inserteds[2] = ' || inserteds[2] )::TEXT AS details,
                      end_time_test - start_time_test AS running_time
             ) t
    );
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue_weekly_test() OWNER TO postgres;

--
-- Name: insert_into_execution_queue_yearly(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue_yearly() RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
    task_check_to_insert RECORD;  -- Usada no loop FOR para inserir na tabela execution_queue
    inserted INTEGER;             -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao
    moment TIMESTAMP;             -- Momento atual + 5 minutos que eh o momento para a proxima execucao
    today DATE;                   -- Data do momento atual

  BEGIN
    moment = date_trunc('minute', clock_now()) + interval '5 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    today = moment::DATE;

    inserted = 0;

    FOR task_check_to_insert IN
    SELECT tc.id, 
           --- dt.hour || ':' || dt.minute AS horario,
           --- ns.notification_type_id,
    
           --- ns.pre_notify_days, ns.pre_notify_hours, ns.pre_notify_minutes, tc.repeats_every,

           -- Periodicidade value e name
           --- pm.key_value AS periodicity_key_value, pm.key_name AS periodicity_key_name,

           -- Inicio de todas as notificacoes
           --- tc.starts_at + (SELECT min(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) - ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') AS inicio_de_todas_as_notificacoes,

           -- Fim de todas as notificacoes
           --- tc.ends_at + (SELECT max(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) AS fim_de_todas_as_notificacoes,

           -- Momento de iniciar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
           --- today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) AS momento_de_iniciar_notiicacao,

           -- Momento de finalizar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
           --- today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) ) * interval '1 minute' ) AS momento_de_finalizar_notiicacao,

           -- Minutos passados desde o inicio das notificacoes
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER AS minutos_passados_desde_o_inicio_das_notificacoes,
       
           -- Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
           --- ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           --- (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           --- AS minutos_passados_desde_o_inicio_das_notificacoes_a_cada_5_min,
       
           -- Notificar Agora
           --(Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos) % (repetir a cada x minutos) = 0
           --- ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           ---  (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
           ---  ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
           ---  (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           --- ) % greatest(1, ns.notify_again_every) = 0
           --- AS notificar_agora,

           -- Dias do mes em que ocorrera a verificacao da tarefa
           --- date_part('DAY', moment + (ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'),

           -- Dentro da periodicidade?
           --- ( SELECT count(*) - 1 FROM generate_series(tc.starts_at, moment + ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'), '1 year' ) ) AS anos_desde_a_primeira_notificacao,  -- Está no dia de notificar (considerando os dias para comecar a notificar)

           -- Proxima notificacao em YYYY-MM-DD hh:mm:ss
           -- Momento de iniciar a notificacao +
           ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' )
           ) +
           -- Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos
           ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
             ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
             (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
           ) * interval '1 minute'
           AS next_execution
       
      FROM task_checks tc 
        INNER JOIN days_times dt ON tc.id = dt.task_check_id
        INNER JOIN notifications ns ON tc.id = ns.task_check_id
        INNER JOIN parameters pm ON tc.periodicity_id = pm.id

      WHERE tc.active AND

            -- Periodicidade ANUAL
            pm.category_name = 'periodicidades' AND pm.key_name = 'anual' AND

            -- Inicio de todas as notificacoes eh menor que o momento atual
            tc.starts_at + (SELECT min(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) - ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute') <= moment AND    -- Inicia antes de hoje ou hoje (considerando os dias, horas e minutos para comecar a notificar)

            -- Fim de todas as notificacoes eh maior que o momento atual
	    ( tc.ends_at ISNULL OR tc.ends_at + (SELECT max(hour*60+minute) * interval '1 minute' FROM days_times WHERE task_check_id = tc.id) >= moment ) AND    -- Nao finaliza hoje (ou depois considerando dias horas e minutos para notificar)

            -- Momento de iniciar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
            -- eh menor ou igual que a hora atual? (ja iniciou o periodo de notificacao)
            today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
            (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) <= moment AND

            -- Momento de finalizar a notificacao: Dia atual + Se(passou da hora? 1 dia, 0 dia) + hora e minuto da verificacao da tarefa - dias e horas e minutos antes para comecar a notificar
            -- eh maior ou igual que a hora atual? (ainda nao terminou o periodo de notificacao)
            today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
            (dt.hour*60 + dt.minute) ) * interval '1 minute' ) >= moment AND

            -- Notificar Agora? (Estah no momento de notificar a cada x minutos?)
            --(Minutos passados desde o inicio das notificacoes arredondado a cada 5 minutos) % (repetir a cada x minutos) = 0
            ( ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
              (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER -
              ( extract('epoch' FROM ( moment - ( today + ( ( ( CASE WHEN extract('hour' FROM moment)*60 + extract('minute' FROM moment) > dt.hour*60 + dt.minute THEN 1*24*60 ELSE 0 END ) +
              (dt.hour*60 + dt.minute) - (ns.pre_notify_days*24*60 + ns.pre_notify_hours*60 + ns.pre_notify_minutes) ) * interval '1 minute' ) ) ) ) / 60)::INTEGER % 5
            ) % greatest(1, ns.notify_again_every) = 0 AND

            -- Dentro da periodicidade?
            ( SELECT count(*) - 1 FROM generate_series(tc.starts_at, moment + ((ns.pre_notify_days * 24 * 60 + ns.pre_notify_hours * 60 + ns.pre_notify_minutes) * interval '1 minute'), '1 year' ) ) % greatest(1,tc.repeats_every) = 0  -- Está no dia de notificar (considerando os dias para comecar a notificar)

    LOOP
      IF ( SELECT count(*) FROM execution_queue WHERE task_check_id = task_check_to_insert.id AND next_execution = task_check_to_insert.next_execution ) = 0 THEN
        -- Nao existe na fila de execucao ainda entao INSERE
        INSERT INTO execution_queue (task_check_id, next_execution) VALUES (task_check_to_insert.id, task_check_to_insert.next_execution);
        inserted = inserted + 1;
      END IF;
    END LOOP;

    RETURN inserted;  -- Quantidades de linhas inseridas na tabela execution_queue
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue_yearly() OWNER TO postgres;

--
-- Name: insert_into_execution_queue_yearly_test(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_into_execution_queue_yearly_test() RETURNS TABLE(function_name character varying, test_passed boolean, details text, running_time interval)
    LANGUAGE plpgsql
    AS $$
  DECLARE
    place_id_test INTEGER;                -- id do local para usar nos testes
    periodicity_id_test INTEGER;          -- id da periodicidade usada nos testes
    date_test DATE;                       -- Data para o teste
    days_time_hour_to_test INTEGER[2];    -- Hora para o Teste
    days_time_minute_to_test INTEGER[2];  -- Minuto para o Teste
    task_check_id_test INTEGER[2];        -- array com os id da verificacao de tarefa que serah testada
    tc_id INTEGER;                        -- id que será armazenado em task_check_id_test

    start_time_test TIMESTAMP;            -- Momento de inicio do teste
    end_time_test   TIMESTAMP;            -- Momento de fim do teste

    task_check_test TEXT;                 -- String JSON com a tarefa a ser inserida e testada

    moment TIMESTAMP;                     -- Momento atual + 5 ou 10 minutos que eh o momento para a proxima execucao (arredondado de 5 em 5 minutos)

    inserteds INTEGER[2];                 -- Quantidade de linhas inseridas na tabela execution_queue e que serah retornada pela funcao
    inserted INTEGER;                     -- Serah armazenado no array inserteds


  BEGIN
    
    PERFORM set_clock_now('2017-08-28T16:55:00');  -- Faz mock do relogio
    start_time_test := clock_now();

    INSERT INTO places (company_id, name, updated_by_user_id) VALUES (1, 'Local apenas para testes das funcoes do banco de dados', 1) RETURNING id INTO place_id_test;
    SELECT INTO periodicity_id_test id FROM parameters WHERE category_name = 'periodicidades' AND key_name = 'anual';

    RAISE NOTICE 'place_id_test = %', place_id_test;
    RAISE NOTICE 'periodicity_id_test = %', periodicity_id_test;

    date_test := clock_now()::DATE;
    moment := date_trunc('minute', clock_now()) + interval '5 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    days_time_hour_to_test[1] := date_part('hour', moment)::INTEGER;
    days_time_minute_to_test[1] := date_part('minute', moment)::INTEGER;

    RAISE NOTICE 'date_test = %, days_time_hour_to_test = %, days_time_minute_to_test = %', date_test, days_time_hour_to_test, days_time_minute_to_test;

    task_check_test :=
      '{ "name": "Teste 1 - SEM ANTECEDECIA E SEM RENOTIFICACAO E NO MESMO ANO",
         "description": "Teste de tarefa anual 1.",
         "place_id": ' || place_id_test || ',
         "user_checker_id": 2,
         "periodicity_id": ' || periodicity_id_test || ',
         "starts_at": "' || date_test || '",
         "ends_at": null,
         "repeats_every": 1,
         "updated_by_user_id": 1,
         "days_times": [ { "hour": ' || days_time_hour_to_test[1] || ', "minute": ' || days_time_minute_to_test[1] || ' } ],
         "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 0, "pre_notify_minutes": 0, "notify_again_every": 0 } ]
       }';

    RAISE NOTICE 'task_check_test = %', task_check_test;

    SELECT INTO tc_id insert_taskcheckjson(task_check_test);
    task_check_id_test[1] := tc_id;

    moment := date_trunc('minute', clock_now()) + interval '15 minutes' - ( ( extract('minute' FROM date_trunc('minute', clock_now()) + interval '5 minutes')::INTEGER % 5 ) * interval '1 minute' );
    days_time_hour_to_test[2] := date_part('hour', moment)::INTEGER;
    days_time_minute_to_test[2] := date_part('minute', moment)::INTEGER;

    task_check_test :=
      '{ "name": "Teste 2 - COM ANTECEDECIA E COM RENOTIFICACAO E NO MESMO ANO",
         "description": "Teste de tarefa anual 2.",
         "place_id": ' || place_id_test || ',
         "user_checker_id": 2,
         "periodicity_id": ' || periodicity_id_test || ',
         "starts_at": "' || date_test || '",
         "ends_at": null,
         "repeats_every": 1,
         "updated_by_user_id": 1,
         "days_times": [ { "hour": ' || days_time_hour_to_test[2] || ', "minute": ' || days_time_minute_to_test[2] || ' } ],
         "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 0, "pre_notify_minutes": 10, "notify_again_every": 5 } ]
       }';

    RAISE NOTICE 'task_check_test = %', task_check_test;

    SELECT INTO tc_id insert_taskcheckjson(task_check_test);
    task_check_id_test[2] := tc_id;

    
--     RAISE NOTICE 'task_check_id_test = %', task_check_id_test;

    --PERFORM set_clock_now('2017-08-28T16:55:01');  -- Faz mock do relogio ou PERFORM pg_sleep(1);

    PERFORM set_clock_now('2017-08-28T16:55:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);
    PERFORM insert_into_execution_queue_yearly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir de 10 minutos antes...', 5;

    PERFORM set_clock_now('2017-08-28T17:00:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_yearly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir de 5 minutos antes...', 5;

    PERFORM set_clock_now('2017-08-28T17:05:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_yearly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    RAISE NOTICE 'Aguardando % minutos a partir do momento da ultima notificacao...', 5;

    PERFORM set_clock_now('2017-08-28T17:10:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_yearly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    PERFORM set_clock_now('2017-08-28T17:15:01');  -- Faz mock do relogio ou PERFORM pg_sleep(5 * 60);

    PERFORM insert_into_execution_queue_yearly();
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    inserteds[1] := inserted;
    SELECT INTO inserted COUNT(id) FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    inserteds[2] := inserted;
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 1: %', inserteds[1];
    RAISE NOTICE 'Inseridos na fila com o id da tarefa 2: %', inserteds[2];

    DELETE FROM execution_queue WHERE task_check_id = task_check_id_test[1];
    DELETE FROM execution_queue WHERE task_check_id = task_check_id_test[2];
    DELETE FROM task_checks WHERE id = task_check_id_test[1];
    DELETE FROM task_checks WHERE id = task_check_id_test[2];
    DELETE FROM places WHERE id = place_id_test;

    RAISE NOTICE 'clock_now(): %', clock_now();
    end_time_test := clock_now();

    PERFORM set_clock_now(NULL);  -- Desfaz mock do relogio

    RETURN QUERY
    (
      SELECT t.function_name, t.test_passed, t.details, t.running_time 
        FROM ( SELECT 'insert_into_execution_queue_yearly()'::VARCHAR(64) AS function_name,
                      (inserteds[1] = 1 AND inserteds[2] = 3) AS test_passed,
                      ('Esperados: inserteds[1] = 1, inserteds[2] = 3' || E'\n' || 'Retornados: inserteds[1] = ' || inserteds[1] || ', inserteds[2] = ' || inserteds[2] )::TEXT AS details,
                      end_time_test - start_time_test AS running_time
             ) t
    );
  END
$$;


ALTER FUNCTION public.insert_into_execution_queue_yearly_test() OWNER TO postgres;

--
-- Name: insert_taskcheckjson(json); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_taskcheckjson(in_json_text json) RETURNS integer
    LANGUAGE plpgsql
    AS $$
  -- Insere na tabela task_check e em suas tabelas relacionadas a partir de uma string JSON.
  -- Exemplo:
  -- SELECT insert_taskcheckjson(
  --   '{ "name": "Conferir sabonete líquido do banheiro feminino",
  --      "description": "Conferir se foi completado até a tampa o sabone líquido do banheiro feminino.",
  --      "place_id": 1,
  --      "user_checker_id": 2,
  --      "periodicity_id": 3,
  --      "starts_at": "2017-05-24",
  --      "ends_at": null,
  --      "repeats_every": 1,
  --      "updated_by_user_id": 1,
  --      "weeks_days": { "sunday": false, "monday": true, "tuesday": true, "wednesday": true, "thursday": true, "friday": true, "saturday": false },
  --      "days_times": [ { "hour": 7, "minute": 40 }, {"hour": 13, "minute": 30 } ],
  --      "notifications": [ { "notification_type_id": 19, "pre_notify_days": 0, "pre_notify_hours": 1, "pre_notify_minutes": 30, "notify_again_every": 10 } ]
  --    }' );

  DECLARE
    returning_id INTEGER;            -- id da tabela task_cheks retornado apos o INSERT
    returning_ubui INTEGER;          -- updated_by_user_id da verificacao da tabela task_cheks retornado apos o INSERT
    weeks_days_text JSON;            -- dias da semana para a tarefa (caso estejam presentes no parametro in_json_text)
    months_days_text JSON;           -- dias do mes para a verificacao da tarefa (caso estejam presentes no parametro in_json_text)
    days_times_text JSON;            -- horas do dia para verificacao da tarefa.
    notifications_text JSON;         -- notificacoes para a tarefa.
    periodicity_id_integer INTEGER;  -- id da parameters (periodicidade)
  BEGIN
    -- Verifica se foi passado um valor NULL como parametro
   IF in_json_text ISNULL THEN
     RAISE EXCEPTION 'Funcao insert_taskcheckjson(in_json_text JSON) nao aceita valor NULL como parametro.' ;
   END IF;
    
    -- coleta as subpartes das tarefas nas variaveis
    weeks_days_text := in_json_text::json->'weeks_days';
    months_days_text := in_json_text::json->'months_days';
    days_times_text := in_json_text::json->'days_times';
    notifications_text := in_json_text::json->'notifications';
    periodicity_id_integer := ( in_json_text::json->'periodicity_id' )::TEXT::INTEGER;

    -- Validacoes necessarias
    IF periodicity_id_integer IN ( SELECT id FROM parameters WHERE category_name = 'periodicidades' AND key_name NOT IN ('semanal', 'mensal') ) THEN
      -- Nao eh semanal e nem mensal
      IF (NOT (weeks_days_text ISNULL OR months_days_text ISNULL)) THEN
        -- Existencia de valor para "weeks_days" ou "months_days" nao permitidas para tuplas nao semanais e nao mensais
        RAISE EXCEPTION 'Dias da semana (weeks_days) e dias do mes nao permitidos para checagens de tarefas (task_checks) nao semanais e nao mensais' ;
      END IF;
    ELSE
      IF (weeks_days_text ISNULL) AND (months_days_text ISNULL) THEN
        -- Existencia de apenas 1 valor para "weeks_days" ou apenas 1 "months_days"
        RAISE EXCEPTION 'Dias da semana (weeks_days) ou dias do mes necessarios' ;
      ELSE
        IF (weeks_days_text ISNULL) THEN
          IF (NOT (json_typeof(months_days_text)::TEXT = 'array')) OR (json_array_length(months_days_text)::INTEGER = 0) THEN
            -- Existencia de apenas 1 valor para "months_days"
            RAISE EXCEPTION 'Dias do mes (months_days) deve ser um array JSON com 1 ou mais elementos necessariamente.' ;
          END IF;
        ELSE
          IF (json_typeof(weeks_days_text)::TEXT = 'array') THEN
            -- Existencia de apenas 1 valor para "week_days"
            RAISE EXCEPTION 'Eh permitido apenas uma tupla para dias da semana (weeks_days) e nao um array de tuplas.' ;
          END IF;
        END IF;
      END IF;
    END IF;
    IF (days_times_text ISNULL) OR
       (NOT (json_typeof(days_times_text)::TEXT = 'array')) OR
       (json_array_length(days_times_text)::INTEGER = 0) THEN
      -- Existencia de 1 ou mais valores para days_times (array)
      RAISE EXCEPTION 'Horas do dia (days_times) deve ser um array JSON com 1 ou mais elementos necessariamente.' ;
    END IF;
    IF (notifications_text ISNULL) OR 
       (NOT (json_typeof(notifications_text)::TEXT = 'array')) OR
       (json_array_length(notifications_text)::INTEGER = 0) THEN
      -- Existencia de 1 ou mais valores para notifications (array)
      RAISE EXCEPTION 'Notificacoes (notidications) deve ser um array JSON com 1 ou mais elementos necessariamente.' ;
    END IF;

    -- Insere em task_cheks
    INSERT INTO task_checks 
      (name, description, place_id, user_checker_id, periodicity_id, starts_at, ends_at, repeats_every, updated_by_user_id)
      SELECT * from json_to_record(in_json_text)  AS task_checks_columns(name TEXT, description TEXT, place_id INT, user_checker_id INT, periodicity_id INT, starts_at TIMESTAMP, ends_at TIMESTAMP, repeats_every INT, updated_by_user_id INT)
      RETURNING id, updated_by_user_id
      INTO returning_id, returning_ubui;

    IF NOT (weeks_days_text) ISNULL THEN
      -- Insere na tabela weeks_days (dias na semana)
      INSERT INTO weeks_days (task_check_id, sunday, monday, tuesday, wednesday, thursday, friday, saturday, updated_by_user_id)
        VALUES ( returning_id, (weeks_days_text->'sunday')::TEXT::BOOLEAN, (weeks_days_text->'monday')::TEXT::BOOLEAN, 
                 (weeks_days_text->'tuesday')::TEXT::BOOLEAN, (weeks_days_text->'wednesday')::TEXT::BOOLEAN,
                 (weeks_days_text->'thursday')::TEXT::BOOLEAN, (weeks_days_text->'friday')::TEXT::BOOLEAN,
                 (weeks_days_text->'saturday')::TEXT::BOOLEAN,
                 returning_ubui );
    END IF;

    IF NOT (months_days_text ISNULL) THEN
      -- Insere na tabela months_days (dias no mes)
      FOR i IN 0..((json_array_length(months_days_text)::INTEGER)-1) LOOP
        INSERT INTO months_days (task_check_id, month_day, updated_by_user_id)
          VALUES ( returning_id, ((months_days_text->i)->'month_day')::TEXT::INTEGER, returning_ubui );
      END LOOP;
    END IF;

    IF NOT (days_times_text ISNULL) THEN
      -- Insere na tabela days_times (horas no dia)
      FOR i IN 0..((json_array_length(days_times_text)::INTEGER)-1) LOOP
        INSERT INTO days_times (task_check_id, hour, minute, updated_by_user_id)
          VALUES ( returning_id, ((days_times_text->i)->'hour')::TEXT::INTEGER, ((days_times_text->i)->'minute')::TEXT::INTEGER,
                   returning_ubui );
      END LOOP;
    END IF;

    IF NOT (days_times_text ISNULL) THEN
      -- Insere na tabela notifications (notificacoes)
      FOR i IN 0..((json_array_length(notifications_text)::INTEGER)-1) LOOP
        INSERT INTO notifications (task_check_id, notification_type_id, pre_notify_days, pre_notify_hours, pre_notify_minutes,
                                   notify_again_every, updated_by_user_id)
          VALUES ( returning_id, ((notifications_text->i)->'notification_type_id')::TEXT::INTEGER,
                   ((notifications_text->i)->'pre_notify_days')::TEXT::INTEGER,
                   ((notifications_text->i)->'pre_notify_hours')::TEXT::INTEGER,
                   ((notifications_text->i)->'pre_notify_minutes')::TEXT::INTEGER,
                   ((notifications_text->i)->'notify_again_every')::TEXT::INTEGER,
                   returning_ubui );
      END LOOP;
    END IF;

    RETURN returning_id;
  END;
$$;


ALTER FUNCTION public.insert_taskcheckjson(in_json_text json) OWNER TO postgres;

--
-- Name: insert_taskcheckjson(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_taskcheckjson(in_json_text text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE
    returning_id INTEGER;

  BEGIN
    returning_id := ( SELECT insert_taskcheckjson(in_json_text::JSON) );

    RETURN returning_id;
  END;
$$;


ALTER FUNCTION public.insert_taskcheckjson(in_json_text text) OWNER TO postgres;

--
-- Name: log_it(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION log_it() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    old_json TEXT;       -- Valor antigo da tupla em formato JSON como TEXT
    current_row RECORD;  -- Valor a ser considerado para obter o JSON, a primary_key e o updated_by_user_id (NEW para INSERT, OLD para UPDATE e DELETE)
    flags RECORD;        -- Flags para indicar o que serah ou nao auditado (INSERT, UPDATE, DELETE)
    primary_key TEXT;    -- Valor da chave primaria (normalmente ID ou outro valor para algumas tabelas especificas)
BEGIN
  IF TG_OP = 'INSERT' THEN
    old_json := NULL;    -- Nao armazena valores anteriores quando eh feito um INSERT
  ELSE
    old_json := to_json(OLD)::TEXT;  -- Valores anteriores em formato JSON como TEXT das colunas da tupla auditada
  END IF;

  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    current_row := NEW;  -- Considera os valores novos das colunas da tupla auditada para obter posteriormente o updated_by_user_id
  ELSE
    current_row := OLD;  -- Considera os valores antigos das colunas da tupla auditada para obter posteriormente o updated_by_user_id
  END IF;

  SELECT INTO flags insert_auditing, update_auditing, delete_auditing FROM audition_tables WHERE table_name = TG_TABLE_NAME::TEXT;
  
  IF (TG_OP = 'INSERT' AND flags.insert_auditing) OR 
     (TG_OP = 'UPDATE' AND flags.update_auditing) OR
     (TG_OP = 'DELETE' AND (flags.delete_auditing ISNULL OR flags.delete_auditing)) THEN

    -- Avaliacao do parametro de chave primaria para tabelas que nao usam a coluna ID
    IF TG_TABLE_NAME = 'audition_tables' THEN
      primary_key := current_row.table_name;  -- table_name eh chave primaria da tabela audition_tables
    -- ELSIF TG_TABLE_NAME = 'outra_tabela_qualquer_que_nao_use_id_como_chave_primaria' THEN
      -- primary_key := expressao_que_represente_a_chave_primaria_ta_tabela;
    ELSE
      primary_key := current_row.id::TEXT;    -- considera o valor da coluna id para armazenamento na primary_key da auditoria
    END IF;
    
    IF (SELECT count(*) > 0 AS present FROM information_schema.columns WHERE table_name = TG_TABLE_NAME::TEXT AND column_name = 'updated_by_user_id' ) THEN      -- Considera a existencia da coluna updated_by_user_id na tabela auditada
      IF current_row.updated_by_user_id ISNULL THEN
        -- Coluna updated_by_user_id estah com valor NULL
        INSERT INTO auditions 
          ( table_name, primary_key, operation, old_values ) 
          VALUES ( TG_TABLE_NAME::TEXT, primary_key, substring(TG_OP::TEXT from 1 for 1), old_json );
      ELSE
        -- Coluna updated_by_user_id nao existe na tabela auditada
        INSERT INTO auditions 
          ( table_name, primary_key, operation, old_values, updated_by_user_id ) 
          VALUES ( TG_TABLE_NAME::TEXT, primary_key, substring(TG_OP::TEXT from 1 for 1), old_json, current_row.updated_by_user_id );
      END IF;
    ELSE
      -- Sem a coluna updated_by_user_id
      INSERT INTO auditions 
        ( table_name, primary_key, operation, old_values ) 
        VALUES ( TG_TABLE_NAME::TEXT, primary_key, substring(TG_OP::TEXT from 1 for 1), old_json );
    END IF;
  END IF;
  RETURN current_row;
END;

$$;


ALTER FUNCTION public.log_it() OWNER TO postgres;

--
-- Name: set_clock_now(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION set_clock_now(time_to_clock text) RETURNS void
    LANGUAGE plpgsql
    AS $$
  BEGIN
    IF time_to_clock ISNULL THEN
      DELETE FROM parameters WHERE category_name = 'Tests' AND key_name = 'clock_mocked_at';
    ELSE
      IF ( SELECT count(id) FROM parameters WHERE category_name = 'Tests' AND key_name = 'clock_mocked_at' ) = 0 THEN
        INSERT INTO parameters (category_name, key_name, key_type, key_value, updated_by_user_id) VALUES ('Tests', 'clock_mocked_at', 'TIMESTAMP', time_to_clock, 1);
      ELSE
        UPDATE parameters SET key_value = time_to_clock WHERE category_name = 'Tests' AND key_name = 'clock_mocked_at';
      END IF;
    END IF;
  END;
$$;


ALTER FUNCTION public.set_clock_now(time_to_clock text) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: audition_tables; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE audition_tables (
    table_name character varying(64) NOT NULL,
    insert_auditing boolean DEFAULT false NOT NULL,
    update_auditing boolean DEFAULT false NOT NULL,
    delete_auditing boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE audition_tables OWNER TO postgres;

--
-- Name: TABLE audition_tables; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE audition_tables IS 'tabelas a serem auditadas e quais quais operacoes geram auditoria (INSERT, UPDATE, DELETE).';


--
-- Name: COLUMN audition_tables.table_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN audition_tables.table_name IS 'nome da tabela a ser auditada.';


--
-- Name: COLUMN audition_tables.insert_auditing; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN audition_tables.insert_auditing IS 'Se true, faz a auditoria durante a operacao INSERT.';


--
-- Name: COLUMN audition_tables.update_auditing; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN audition_tables.update_auditing IS 'Se true, faz a auditoria durante a operacao UPDATE.';


--
-- Name: COLUMN audition_tables.delete_auditing; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN audition_tables.delete_auditing IS 'Se true, faz a auditoria durante a operacao DELETE.
Unica operacao a ter valor padrao true.';


--
-- Name: auditions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE auditions (
    id integer NOT NULL,
    table_name character varying(64) NOT NULL,
    operation character(1) NOT NULL,
    primary_key character varying(250) NOT NULL,
    old_values text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by_user_id integer
);


ALTER TABLE auditions OWNER TO postgres;

--
-- Name: COLUMN auditions.table_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN auditions.table_name IS 'nome da tabela a ser auditada.';


--
-- Name: COLUMN auditions.operation; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN auditions.operation IS 'Operacao: I=INSERT, U=UPDATE, D=DELETE.';


--
-- Name: COLUMN auditions.primary_key; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN auditions.primary_key IS 'Valor da chave primaria (normalmente o id, mas tambem pode ser valores concatenados de chaves primarias compostas).';


--
-- Name: COLUMN auditions.old_values; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN auditions.old_values IS 'Valores das colunas expresso em JSON.
Nulo para inclusao.
Valores antigos da tupla para atualizacao.
Valores atuais da tupla para exclusao.';


--
-- Name: COLUMN auditions.updated_by_user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN auditions.updated_by_user_id IS 'id do usuario que fez a operacao';


--
-- Name: auditions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE auditions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE auditions_id_seq OWNER TO postgres;

--
-- Name: auditions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE auditions_id_seq OWNED BY auditions.id;


--
-- Name: companies; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE companies (
    id integer NOT NULL,
    name character varying(60) NOT NULL,
    nick_name character varying(60) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by_user_id integer
);


ALTER TABLE companies OWNER TO postgres;

--
-- Name: COLUMN companies.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN companies.name IS 'Nome ou Razão Social da Empresa';


--
-- Name: COLUMN companies.nick_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN companies.nick_name IS 'Apelido ou Nome Fantasia da Empresa.';


--
-- Name: COLUMN companies.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN companies.created_at IS 'Data e hora da criação.';


--
-- Name: COLUMN companies.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN companies.updated_at IS 'Data e hora da última modificação.';


--
-- Name: COLUMN companies.updated_by_user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN companies.updated_by_user_id IS 'Usuário que fez a útlima modificação empresa.';


--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE companies_id_seq OWNER TO postgres;

--
-- Name: companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE companies_id_seq OWNED BY companies.id;


--
-- Name: days_times; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE days_times (
    id integer NOT NULL,
    task_check_id integer NOT NULL,
    hour numeric(2,0) NOT NULL,
    minute numeric(2,0) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by_user_id integer NOT NULL,
    CONSTRAINT day_times_minute_divisible_by_5 CHECK (((minute % (5)::numeric) = (0)::numeric))
);


ALTER TABLE days_times OWNER TO postgres;

--
-- Name: TABLE days_times; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE days_times IS 'Horários do dia.';


--
-- Name: COLUMN days_times.hour; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN days_times.hour IS 'Hora do dia';


--
-- Name: COLUMN days_times.minute; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN days_times.minute IS 'Minuto da Hora do dia.';


--
-- Name: COLUMN days_times.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN days_times.created_at IS 'Data e hora da criação.';


--
-- Name: COLUMN days_times.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN days_times.updated_at IS 'Data e hora da última modificação.';


--
-- Name: COLUMN days_times.updated_by_user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN days_times.updated_by_user_id IS 'Usuário que fez a útlima modificação empresa.';


--
-- Name: days_times_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE days_times_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE days_times_id_seq OWNER TO postgres;

--
-- Name: days_times_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE days_times_id_seq OWNED BY days_times.id;


--
-- Name: execution_queue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE execution_queue (
    id integer NOT NULL,
    task_check_id integer NOT NULL,
    executed boolean DEFAULT false NOT NULL,
    next_execution timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE execution_queue OWNER TO postgres;

--
-- Name: TABLE execution_queue; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE execution_queue IS 'Fila para execucao de envio de notificacoes.';


--
-- Name: COLUMN execution_queue.executed; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN execution_queue.executed IS 'Quando o valor for mudado para true, a tupla serah copiada para a tabela auditings e entao excluida.';


--
-- Name: COLUMN execution_queue.next_execution; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN execution_queue.next_execution IS 'Data e hora para a proxima execucao de envio de notificacoes.';


--
-- Name: execution_queue_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE execution_queue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE execution_queue_id_seq OWNER TO postgres;

--
-- Name: execution_queue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE execution_queue_id_seq OWNED BY execution_queue.id;


--
-- Name: migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE migrations (
    db_version character varying(250) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE migrations OWNER TO postgres;

--
-- Name: TABLE migrations; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE migrations IS 'Quando a estrutura do banco muda as se adicionar, modificar ou excluir uma relacao, deverah ficar registrado nessa tabela.';


--
-- Name: COLUMN migrations.db_version; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN migrations.db_version IS 'Versao em uso para o banco de dados.';


--
-- Name: COLUMN migrations.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN migrations.created_at IS 'Data e hora em que foi feita a mudança para esta versao.';


--
-- Name: months_days; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE months_days (
    id integer NOT NULL,
    task_check_id integer NOT NULL,
    month_day integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by_user_id integer NOT NULL
);


ALTER TABLE months_days OWNER TO postgres;

--
-- Name: TABLE months_days; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE months_days IS 'Dias do mês em que a tarefa será conferida.';


--
-- Name: COLUMN months_days.month_day; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN months_days.month_day IS 'Dias de 1 a 31.';


--
-- Name: COLUMN months_days.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN months_days.created_at IS 'Data e hora da criação.';


--
-- Name: COLUMN months_days.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN months_days.updated_at IS 'Data e hora da última modificação.';


--
-- Name: COLUMN months_days.updated_by_user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN months_days.updated_by_user_id IS 'Usuário que fez a útlima modificação empresa.';


--
-- Name: months_days_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE months_days_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE months_days_id_seq OWNER TO postgres;

--
-- Name: months_days_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE months_days_id_seq OWNED BY months_days.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE notifications (
    id integer NOT NULL,
    task_check_id integer NOT NULL,
    notification_type_id integer NOT NULL,
    pre_notify_days integer DEFAULT 0 NOT NULL,
    pre_notify_hours integer DEFAULT 0 NOT NULL,
    pre_notify_minutes integer DEFAULT 10 NOT NULL,
    notify_again_every integer DEFAULT 5 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by_user_id integer NOT NULL,
    CONSTRAINT notifications_notify_again_every_divisible_by_5 CHECK (((notify_again_every % 5) = 0)),
    CONSTRAINT notifications_pre_notify_minutes_divisible_by_5 CHECK (((pre_notify_minutes % 5) = 0))
);


ALTER TABLE notifications OWNER TO postgres;

--
-- Name: COLUMN notifications.pre_notify_days; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN notifications.pre_notify_days IS 'Avisar com antecedência de x dias.';


--
-- Name: COLUMN notifications.pre_notify_hours; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN notifications.pre_notify_hours IS 'Avisar com antecedência de x horas.';


--
-- Name: COLUMN notifications.pre_notify_minutes; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN notifications.pre_notify_minutes IS 'IMPORTANTE: MULTIPLOS DE 5 MINUTOS. Avisar com antecedência de x minutos.';


--
-- Name: COLUMN notifications.notify_again_every; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN notifications.notify_again_every IS 'Notificar novamente a cada x minutos.';


--
-- Name: COLUMN notifications.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN notifications.created_at IS 'Data e hora da criação.';


--
-- Name: COLUMN notifications.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN notifications.updated_at IS 'Data e hora da última modificação.';


--
-- Name: COLUMN notifications.updated_by_user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN notifications.updated_by_user_id IS 'Usuário que fez a útlima modificação empresa.';


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE notifications_id_seq OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE notifications_id_seq OWNED BY notifications.id;


--
-- Name: parameters; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE parameters (
    id integer NOT NULL,
    category_name character varying(60) NOT NULL,
    key_name character varying(60) NOT NULL,
    key_type character varying(32) NOT NULL,
    key_value text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by_user_id integer NOT NULL
);


ALTER TABLE parameters OWNER TO postgres;

--
-- Name: TABLE parameters; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE parameters IS 'Chaves e valores para a categoria Periodicidade:
Única vez = 1
Diário = 2
Semanal = 3
Mensal = 4
Anual = 5

-----------

Chaves e valores para a categoria Meses:
Janeiro = 1
Fevereiro = 2
Março = 3
Abril = 4
Maio = 5
Junho = 6
Julho = 7
Agosto = 8
Setembro = 9
Outubro = 10
Novembro = 11
Dezembro = 12

---------------

Chaves e valores para a categoria Tipo_Notificacao:
Aviso_Impresso = 1
E-mail = 2
Mensagem_Movel = 3
Aviso_Pop_Up = 4

---------------------

Chaves e valores para a categoria Unidades_Tempo:
Minuto = 1
Hora = 2
Dia = 3
Semana = 4
Mês = 5
Ano = 6

---------------------';


--
-- Name: COLUMN parameters.category_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN parameters.category_name IS 'Nome da categoria do parâmetro, por exemplo: Periodicidade';


--
-- Name: COLUMN parameters.key_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN parameters.key_name IS 'Nome da chave do parâmetro. Por exemplo: Diária';


--
-- Name: COLUMN parameters.key_type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN parameters.key_type IS 'Tipo do valor do parâmetro. Por exemplo: String, Integer, Float, Boolean, Date, Timestamp, Binary, JSON.';


--
-- Name: COLUMN parameters.key_value; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN parameters.key_value IS 'Valor do parâmetro. Sempre gravado como string, porém respeitando o tipo definido na coluna chave_tipo (key_type). Por exemplo para a chave Diária o valor será definido como 2 (ver comentário da coluna periodicidade_id na tabela tarefa_conferencias).';


--
-- Name: COLUMN parameters.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN parameters.created_at IS 'Data e hora da criação.';


--
-- Name: COLUMN parameters.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN parameters.updated_at IS 'Data e hora da última modificação.';


--
-- Name: COLUMN parameters.updated_by_user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN parameters.updated_by_user_id IS 'Usuário que fez a útlima modificação empresa.';


--
-- Name: parameters_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE parameters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE parameters_id_seq OWNER TO postgres;

--
-- Name: parameters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE parameters_id_seq OWNED BY parameters.id;


--
-- Name: places; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE places (
    id integer NOT NULL,
    company_id integer NOT NULL,
    name character varying(60) NOT NULL,
    description text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by_user_id integer NOT NULL
);


ALTER TABLE places OWNER TO postgres;

--
-- Name: COLUMN places.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN places.name IS 'Nome do local dentro da empresa.';


--
-- Name: COLUMN places.description; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN places.description IS 'Descrição do local dentro da empresa.';


--
-- Name: COLUMN places.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN places.created_at IS 'Data e hora da criação.';


--
-- Name: COLUMN places.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN places.updated_at IS 'Data e hora da última modificação.';


--
-- Name: COLUMN places.updated_by_user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN places.updated_by_user_id IS 'Usuário que fez a útlima modificação empresa.';


--
-- Name: places_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE places_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE places_id_seq OWNER TO postgres;

--
-- Name: places_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE places_id_seq OWNED BY places.id;


--
-- Name: seeds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE seeds (
    seed_version character varying(250) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE seeds OWNER TO postgres;

--
-- Name: TABLE seeds; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE seeds IS 'Quando o banco de dados eh populado, ficarah registrado aqui nessa tabela.';


--
-- Name: COLUMN seeds.seed_version; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN seeds.seed_version IS 'Versao de quando populou o banco de dados.';


--
-- Name: COLUMN seeds.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN seeds.created_at IS 'Data e hora em que foi feita a mudança para esta versao.';


--
-- Name: task_checks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE task_checks (
    id integer NOT NULL,
    name character varying(60) NOT NULL,
    description text,
    place_id integer NOT NULL,
    user_checker_id integer NOT NULL,
    periodicity_id integer NOT NULL,
    starts_at date NOT NULL,
    ends_at date,
    repeats_every integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by_user_id integer NOT NULL,
    active boolean DEFAULT true NOT NULL
);


ALTER TABLE task_checks OWNER TO postgres;

--
-- Name: TABLE task_checks; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE task_checks IS 'Cadastro de tarefas a serem conferidas.';


--
-- Name: COLUMN task_checks.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.name IS 'Nome da Tarefa a ser conferida (What).';


--
-- Name: COLUMN task_checks.description; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.description IS 'Descrição detalhada da tarefa a ser conferida (Why).';


--
-- Name: COLUMN task_checks.place_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.place_id IS 'Local (Where) onde a tarefa será conferida.';


--
-- Name: COLUMN task_checks.user_checker_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.user_checker_id IS 'Usuário conferente (Who) que checará se a tarefa foi executada ou não.';


--
-- Name: COLUMN task_checks.periodicity_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.periodicity_id IS 'Periodicidade da Tarefa buscada na tabela parametros (parameters) para a categoria (cotegory_name) Periodicidades:
1. Única vez
2. Diário
3. Semanal
4. Mensal
5. Anual';


--
-- Name: COLUMN task_checks.starts_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.starts_at IS 'Data de início da verificação da tarefa.';


--
-- Name: COLUMN task_checks.ends_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.ends_at IS 'Data em que termina. NULL para NÃO termina.';


--
-- Name: COLUMN task_checks.repeats_every; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.repeats_every IS 'Repetir a cada x dias, semanas etc.';


--
-- Name: COLUMN task_checks.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.created_at IS 'Data e hora da criação.';


--
-- Name: COLUMN task_checks.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.updated_at IS 'Data e hora da última modificação.';


--
-- Name: COLUMN task_checks.updated_by_user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN task_checks.updated_by_user_id IS 'Usuário que fez a útlima modificação empresa.';


--
-- Name: task_checks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE task_checks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE task_checks_id_seq OWNER TO postgres;

--
-- Name: task_checks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE task_checks_id_seq OWNED BY task_checks.id;


--
-- Name: teste; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE teste (
    id integer,
    nome character varying(2000)
);


ALTER TABLE teste OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE users (
    id integer NOT NULL,
    user_name character varying(20) NOT NULL,
    password character varying(255) NOT NULL,
    name character varying(60) NOT NULL,
    email character varying(255),
    mobile_message character varying(20),
    cpf character varying(20) NOT NULL,
    administrator boolean DEFAULT false NOT NULL,
    company_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by_user_id integer
);


ALTER TABLE users OWNER TO postgres;

--
-- Name: COLUMN users.user_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.user_name IS 'Nome do usuário sem espaços e com preenchimento obrigatoriamente em minúsculas permitindo também números e underline. [a-z0-9_]{20}';


--
-- Name: COLUMN users.password; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.password IS 'Senha criptografada.';


--
-- Name: COLUMN users.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.name IS 'Nome inteiro da pessoa.';


--
-- Name: COLUMN users.email; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.email IS 'Preenchimento obrigadorio para o caso de ser usuário administrador (administrator = true).';


--
-- Name: COLUMN users.cpf; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.cpf IS 'CPF do usuário.';


--
-- Name: COLUMN users.administrator; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.administrator IS 'true se o usuário for um dos administradores da empresa.';


--
-- Name: COLUMN users.company_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.company_id IS 'Usado como chave estrangeira para a tabela copanies (empresas).';


--
-- Name: COLUMN users.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.created_at IS 'Data e hora da criação.';


--
-- Name: COLUMN users.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.updated_at IS 'Data e hora da última modificação.';


--
-- Name: COLUMN users.updated_by_user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.updated_by_user_id IS 'Usuário que alterou os dados da tupla pela última vez, podendo ficar nulo.';


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: weeks_days; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE weeks_days (
    id integer NOT NULL,
    task_check_id integer NOT NULL,
    sunday boolean DEFAULT false NOT NULL,
    monday boolean DEFAULT false NOT NULL,
    tuesday boolean DEFAULT false NOT NULL,
    wednesday boolean DEFAULT false NOT NULL,
    thursday boolean DEFAULT false NOT NULL,
    friday boolean DEFAULT false NOT NULL,
    saturday boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by_user_id integer NOT NULL
);


ALTER TABLE weeks_days OWNER TO postgres;

--
-- Name: TABLE weeks_days; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE weeks_days IS 'Dias da semana em que a tarefa será checada.';


--
-- Name: COLUMN weeks_days.created_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN weeks_days.created_at IS 'Data e hora da criação.';


--
-- Name: COLUMN weeks_days.updated_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN weeks_days.updated_at IS 'Data e hora da última modificação.';


--
-- Name: COLUMN weeks_days.updated_by_user_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN weeks_days.updated_by_user_id IS 'Usuário que fez a útlima modificação empresa.';


--
-- Name: weeks_days_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE weeks_days_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE weeks_days_id_seq OWNER TO postgres;

--
-- Name: weeks_days_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE weeks_days_id_seq OWNED BY weeks_days.id;


--
-- Name: auditions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auditions ALTER COLUMN id SET DEFAULT nextval('auditions_id_seq'::regclass);


--
-- Name: companies id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY companies ALTER COLUMN id SET DEFAULT nextval('companies_id_seq'::regclass);


--
-- Name: days_times id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY days_times ALTER COLUMN id SET DEFAULT nextval('days_times_id_seq'::regclass);


--
-- Name: execution_queue id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY execution_queue ALTER COLUMN id SET DEFAULT nextval('execution_queue_id_seq'::regclass);


--
-- Name: months_days id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY months_days ALTER COLUMN id SET DEFAULT nextval('months_days_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY notifications ALTER COLUMN id SET DEFAULT nextval('notifications_id_seq'::regclass);


--
-- Name: parameters id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY parameters ALTER COLUMN id SET DEFAULT nextval('parameters_id_seq'::regclass);


--
-- Name: places id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY places ALTER COLUMN id SET DEFAULT nextval('places_id_seq'::regclass);


--
-- Name: task_checks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY task_checks ALTER COLUMN id SET DEFAULT nextval('task_checks_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: weeks_days id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY weeks_days ALTER COLUMN id SET DEFAULT nextval('weeks_days_id_seq'::regclass);


--
-- Data for Name: audition_tables; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY audition_tables (table_name, insert_auditing, update_auditing, delete_auditing, created_at, updated_at) FROM stdin;
audition_tables	t	t	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
companies	t	t	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
days_times	f	f	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
execution_queue	t	t	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
months_days	f	f	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
notifications	f	f	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
parameters	t	t	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
places	t	t	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
task_checks	f	f	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
users	t	t	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
weeks_days	f	f	t	2017-08-11 23:17:41.983774	2017-08-11 23:17:41.983774
\.


--
-- Data for Name: auditions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY auditions (id, table_name, operation, primary_key, old_values, created_at, updated_by_user_id) FROM stdin;
1	audition_tables	I	audition_tables	\N	2017-08-11 23:17:41.983774	\N
2	audition_tables	I	companies	\N	2017-08-11 23:17:41.983774	\N
3	audition_tables	I	days_times	\N	2017-08-11 23:17:41.983774	\N
4	audition_tables	I	execution_queue	\N	2017-08-11 23:17:41.983774	\N
5	audition_tables	I	months_days	\N	2017-08-11 23:17:41.983774	\N
6	audition_tables	I	notifications	\N	2017-08-11 23:17:41.983774	\N
7	audition_tables	I	parameters	\N	2017-08-11 23:17:41.983774	\N
8	audition_tables	I	places	\N	2017-08-11 23:17:41.983774	\N
9	audition_tables	I	task_checks	\N	2017-08-11 23:17:41.983774	\N
10	audition_tables	I	users	\N	2017-08-11 23:17:41.983774	\N
11	audition_tables	I	weeks_days	\N	2017-08-11 23:17:41.983774	\N
12	companies	I	1	\N	2017-08-19 09:19:13.457107	\N
13	users	I	1	\N	2017-08-19 09:19:13.457107	\N
14	users	U	1	{"id":1,"user_name":"luisfernandoweb","password":"b0c36fd6b5254cbf5665d7e414fd0ee2","name":"Luís Fernando","email":"luisfernandoweb@gmail.com","mobile_message":"+5519994230576","cpf":"13742083880","administrator":true,"company_id":1,"created_at":"2017-08-19T09:19:13.457107","updated_at":"2017-08-19T09:19:13.457107","updated_by_user_id":null}	2017-08-19 09:19:13.457107	1
15	companies	U	1	{"id":1,"name":"Empresa Testes Ltda","nick_name":"Empresa Testes, A Melhor","created_at":"2017-08-19T09:19:13.457107","updated_at":"2017-08-19T09:19:13.457107","updated_by_user_id":null}	2017-08-19 09:19:13.457107	1
16	parameters	I	1	\N	2017-08-19 09:19:17.796554	1
17	parameters	I	2	\N	2017-08-19 09:19:17.796554	1
18	parameters	I	3	\N	2017-08-19 09:19:17.796554	1
19	parameters	I	4	\N	2017-08-19 09:19:17.796554	1
20	parameters	I	5	\N	2017-08-19 09:19:17.796554	1
21	parameters	I	6	\N	2017-08-19 09:19:17.796554	1
22	parameters	I	7	\N	2017-08-19 09:19:17.796554	1
23	parameters	I	8	\N	2017-08-19 09:19:17.796554	1
24	parameters	I	9	\N	2017-08-19 09:19:17.796554	1
25	parameters	I	10	\N	2017-08-19 09:19:17.796554	1
26	parameters	I	11	\N	2017-08-19 09:19:17.796554	1
27	parameters	I	12	\N	2017-08-19 09:19:17.796554	1
28	parameters	I	13	\N	2017-08-19 09:19:17.796554	1
29	parameters	I	14	\N	2017-08-19 09:19:17.796554	1
30	parameters	I	15	\N	2017-08-19 09:19:17.796554	1
31	parameters	I	16	\N	2017-08-19 09:19:17.796554	1
32	parameters	I	17	\N	2017-08-19 09:19:17.796554	1
33	parameters	I	18	\N	2017-08-19 09:19:17.796554	1
34	parameters	I	19	\N	2017-08-19 09:19:17.796554	1
35	parameters	I	20	\N	2017-08-19 09:19:17.796554	1
36	parameters	I	21	\N	2017-08-19 09:19:17.796554	1
37	parameters	I	22	\N	2017-08-19 09:19:17.796554	1
38	parameters	I	23	\N	2017-08-19 09:19:17.796554	1
39	parameters	I	24	\N	2017-08-19 09:19:17.796554	1
40	parameters	I	25	\N	2017-08-19 09:19:17.796554	1
41	parameters	I	26	\N	2017-08-19 09:19:17.796554	1
42	parameters	I	27	\N	2017-08-19 09:19:17.796554	1
43	places	I	1	\N	2017-08-19 09:19:23.066624	1
44	users	I	2	\N	2017-08-19 09:19:33.252524	1
45	users	I	3	\N	2017-08-19 09:19:33.252524	1
46	places	I	2	\N	2017-08-19 09:19:53.338071	1
47	companies	I	2	\N	2017-09-02 14:08:01.3612	1
48	companies	U	1	{"id":1,"name":"Empresa Testes Ltda","nick_name":"Empresa Testes, A Melhor","created_at":"2017-08-19T09:19:13.457107","updated_at":"2017-08-19T09:19:13.457107","updated_by_user_id":1}	2017-09-02 14:08:35.547188	1
49	companies	U	2	{"id":2,"name":"XPTO Company Co.","nick_name":"XPTO","created_at":"2017-09-02T14:08:01.3612","updated_at":"2017-09-02T14:08:01.3612","updated_by_user_id":1}	2017-09-02 14:08:42.216391	1
50	companies	U	1	{"id":1,"name":"XPTO Company Co.","nick_name":"XPTO","created_at":"2017-08-19T09:19:13.457107","updated_at":"2017-09-02T14:08:35.547188","updated_by_user_id":1}	2017-09-02 14:08:47.184627	1
51	companies	U	1	{"id":1,"name":"XPTO Company Co.","nick_name":"XPTO","created_at":"2017-08-19T09:19:13.457107","updated_at":"2017-09-02T14:08:47.184627","updated_by_user_id":1}	2017-09-02 14:10:22.847006	1
52	companies	U	1	{"id":1,"name":"XPTO Company Co.","nick_name":"Empresa Testes","created_at":"2017-08-19T09:19:13.457107","updated_at":"2017-09-02T14:10:22.847006","updated_by_user_id":1}	2017-09-02 14:10:54.542025	1
53	companies	U	1	{"id":1,"name":"XPTO Company Co.","nick_name":"Empresa Testes A Melhor","created_at":"2017-08-19T09:19:13.457107","updated_at":"2017-09-02T14:10:54.542025","updated_by_user_id":1}	2017-09-02 14:11:03.164708	1
54	places	U	2	{"id":2,"company_id":1,"name":"Recepção","description":null,"created_at":"2017-08-19T09:19:53.338071","updated_at":"2017-08-19T09:19:53.338071","updated_by_user_id":1}	2017-09-23 10:12:01.891692	1
55	places	U	2	{"id":2,"company_id":1,"name":"Recepção","description":null,"created_at":"2017-08-19T09:19:53.338071","updated_at":"2017-09-23T10:12:01.891692","updated_by_user_id":1}	2017-09-23 10:12:12.2759	1
56	places	U	2	{"id":2,"company_id":1,"name":"Recepção","description":"","created_at":"2017-08-19T09:19:53.338071","updated_at":"2017-09-23T10:12:12.2759","updated_by_user_id":1}	2017-09-23 10:12:22.316121	1
\.


--
-- Name: auditions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('auditions_id_seq', 56, true);


--
-- Data for Name: companies; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY companies (id, name, nick_name, created_at, updated_at, updated_by_user_id) FROM stdin;
2	XPTO Company Co.	XPTO	2017-09-02 14:08:01.3612	2017-09-02 14:08:42.216391	1
1	Empresa Testes	Empresa Testes A Melhor	2017-08-19 09:19:13.457107	2017-09-02 14:11:03.164708	1
\.


--
-- Name: companies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('companies_id_seq', 2, true);


--
-- Data for Name: days_times; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY days_times (id, task_check_id, hour, minute, created_at, updated_at, updated_by_user_id) FROM stdin;
1	1	7	40	2017-08-19 09:19:39.312127	2017-08-19 09:19:39.312127	1
2	1	13	30	2017-08-19 09:19:39.312127	2017-08-19 09:19:39.312127	1
3	2	7	40	2017-08-19 09:19:53.338071	2017-08-19 09:19:53.338071	1
4	2	13	30	2017-08-19 09:19:53.338071	2017-08-19 09:19:53.338071	1
5	3	12	0	2017-08-19 09:20:14.353154	2017-08-19 09:20:14.353154	1
6	3	13	30	2017-08-19 09:20:14.353154	2017-08-19 09:20:14.353154	1
7	4	15	20	2017-08-19 09:20:31.076926	2017-08-19 09:20:31.076926	1
8	4	21	30	2017-08-19 09:20:31.076926	2017-08-19 09:20:31.076926	1
9	5	10	20	2017-08-19 09:20:35.159311	2017-08-19 09:20:35.159311	1
10	5	16	30	2017-08-19 09:20:35.159311	2017-08-19 09:20:35.159311	1
11	6	9	30	2017-09-02 10:19:32.568313	2017-09-02 10:19:32.568313	1
\.


--
-- Name: days_times_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('days_times_id_seq', 11, true);


--
-- Data for Name: execution_queue; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY execution_queue (id, task_check_id, executed, next_execution, created_at) FROM stdin;
\.


--
-- Name: execution_queue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('execution_queue_id_seq', 1, false);


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY migrations (db_version, created_at) FROM stdin;
00000_create_database_relations	2017-08-11 23:16:58.565739
00001_create_trigger_before_update_updated_at	2017-08-11 23:17:10.794901
00002_define_constraint_for_columns_uniques	2017-08-11 23:17:15.448516
00003_alter_bytea_to_text	2017-08-11 23:17:19.313996
00004_set_default_created_at_and_updated_at	2017-08-11 23:17:24.171184
00005_create_function_insert_place_json	2017-08-11 23:17:28.147879
00006_create_function_insert_task_check_json	2017-08-11 23:17:32.998365
00007_create_trigger_log_auditions	2017-08-11 23:17:37.792098
00008_add_trigger_log_it_to_tables	2017-08-11 23:17:41.983774
00009_create_trigger_execution_queue_delete_after_update_executed_sets_true	2017-08-11 23:17:46.530374
00010_create_function_insert_into_execution_queue	2017-08-11 23:17:56.631965
00011_create_function_insert_task_check_json_text	2017-08-11 23:18:01.049882
00012_replace_constraints_to_cascade_for_delete_on_references_task_checks	2017-08-11 23:18:04.813366
00013_create_function_insert_into_execution_queue_monthly	2017-08-11 23:18:08.686094
00014_create_function_insert_into_execution_queue_weekly	2017-08-11 23:18:12.721452
00015_replace_function_insert_task_check_json	2017-08-11 23:18:16.197579
00016_create_function_insert_into_execution_queue_one_time	2017-08-11 23:18:20.851776
00017_create_function_insert_into_execution_queue_daily	2017-08-11 23:18:26.102802
00018_create_function_insert_into_execution_queue_yearly	2017-08-11 23:18:32.871248
00019_replace_function_insert_into_execution_queue	2017-08-11 23:18:37.644506
00020_replace_function_insert_task_check_json	2017-08-11 23:18:42.428161
00021_drop_function_insert_place_json	2017-08-11 23:18:47.978386
00022_create_function_execution_queue_to_json	2017-08-19 11:58:45.499121
00023_add_check_5_in_5_minutes_to_time_columns	2017-08-19 11:58:49.872285
00024_set_timezone_to_brasilia	2017-08-19 11:59:57.272934
00025_create_function_clock_now_and_set_clock_now	2017-09-02 09:39:42.120421
00026_replace_function_insert_into_execution_queue_one_time	2017-09-02 09:40:16.933035
00027_create_function_insert_into_execution_queue_time_test	2017-09-02 09:40:23.20916
00028_add_constraint_notifications_notify_again_every_divisible_by_5	2017-09-02 09:40:26.915948
00029_replace_function_insert_into_execution_queue_daily	2017-09-02 09:40:32.181312
00030_create_function_insert_into_execution_queue_daily_test	2017-09-02 09:40:37.424387
00031_replace_function_insert_into_execution_queue_weekly	2017-09-02 12:45:39.596571
00032_create_function_insert_into_execution_queue_weekly_test	2017-09-02 12:45:44.682972
00033_replace_function_insert_into_execution_queue_monthly	2017-09-09 09:07:02.779022
00034_create_function_insert_into_execution_queue_monthly_test	2017-09-09 09:07:10.299673
00035_replace_function_insert_into_execution_queue_yearly	2017-09-23 08:26:16.615437
00036_create_function_insert_into_execution_queue_yearly_test	2017-09-23 08:26:24.658594
\.


--
-- Data for Name: months_days; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY months_days (id, task_check_id, month_day, created_at, updated_at, updated_by_user_id) FROM stdin;
1	2	7	2017-08-19 09:19:53.338071	2017-08-19 09:19:53.338071	1
2	2	22	2017-08-19 09:19:53.338071	2017-08-19 09:19:53.338071	1
\.


--
-- Name: months_days_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('months_days_id_seq', 2, true);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY notifications (id, task_check_id, notification_type_id, pre_notify_days, pre_notify_hours, pre_notify_minutes, notify_again_every, created_at, updated_at, updated_by_user_id) FROM stdin;
1	1	19	0	1	30	10	2017-08-19 09:19:39.312127	2017-08-19 09:19:39.312127	1
2	2	19	0	1	30	10	2017-08-19 09:19:53.338071	2017-08-19 09:19:53.338071	1
3	3	19	0	0	10	10	2017-08-19 09:20:14.353154	2017-08-19 09:20:14.353154	1
4	4	19	0	0	15	5	2017-08-19 09:20:31.076926	2017-08-19 09:20:31.076926	1
5	5	19	0	0	15	5	2017-08-19 09:20:35.159311	2017-08-19 09:20:35.159311	1
6	6	19	0	0	5	5	2017-09-02 10:19:32.568313	2017-09-02 10:19:32.568313	1
\.


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('notifications_id_seq', 6, true);


--
-- Data for Name: parameters; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY parameters (id, category_name, key_name, key_type, key_value, created_at, updated_at, updated_by_user_id) FROM stdin;
1	periodicidades	unica_vez	integer	1	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
2	periodicidades	diario	integer	2	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
3	periodicidades	semanal	integer	3	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
4	periodicidades	mensal	integer	4	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
5	periodicidades	anual	integer	5	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
6	meses	janeiro	integer	1	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
7	meses	fevereiro	integer	2	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
8	meses	marco	integer	3	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
9	meses	abril	integer	4	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
10	meses	maio	integer	5	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
11	meses	junho	integer	6	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
12	meses	julho	integer	7	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
13	meses	agosto	integer	8	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
14	meses	setembro	integer	9	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
15	meses	outubro	integer	10	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
16	meses	novembro	integer	11	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
17	meses	dezembro	integer	12	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
18	tipos_notificacoes	aviso_impresso	integer	1	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
19	tipos_notificacoes	e-mail	integer	2	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
20	tipos_notificacoes	mensagem_movel	integer	3	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
21	tipos_notificacoes	aviso_pop_up	integer	4	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
22	unidades_tempo	minuto	integer	1	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
23	unidades_tempo	hora	integer	2	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
24	unidades_tempo	dia	integer	3	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
25	unidades_tempo	semana	integer	4	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
26	unidades_tempo	mes	integer	5	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
27	unidades_tempo	ano	integer	6	2017-08-19 09:19:17.796554	2017-08-19 09:19:17.796554	1
\.


--
-- Name: parameters_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('parameters_id_seq', 27, true);


--
-- Data for Name: places; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY places (id, company_id, name, description, created_at, updated_at, updated_by_user_id) FROM stdin;
1	1	Banheiro Feminino	Banheiro Feminino no Térreo.	2017-08-19 09:19:23.066624	2017-08-19 09:19:23.066624	1
2	1	Recepção	\N	2017-08-19 09:19:53.338071	2017-09-23 10:12:22.316121	1
\.


--
-- Name: places_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('places_id_seq', 2, true);


--
-- Data for Name: seeds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY seeds (seed_version, created_at) FROM stdin;
00001_create_company_and_user	2017-08-19 09:19:13.457107
00002_create_parameters	2017-08-19 09:19:17.796554
00003_create_place_banheiro_feminino	2017-08-19 09:19:23.066624
00004_create_users_fernando_silva_and_luis_fernando_lftec	2017-08-19 09:19:33.252524
00005_create_task_check_conferir_banheiro_feminino	2017-08-19 09:19:39.312127
\.


--
-- Data for Name: task_checks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY task_checks (id, name, description, place_id, user_checker_id, periodicity_id, starts_at, ends_at, repeats_every, created_at, updated_at, updated_by_user_id, active) FROM stdin;
1	Conferir sabonete líquido do banheiro feminino	Conferir se foi completado até a tampa o sabone líquido do banheiro feminino.	1	2	3	2017-05-24	\N	1	2017-08-19 09:19:39.312127	2017-08-19 09:19:39.312127	1	t
2	Conferir relógio de força	Conferir marcação de consumo de energia elétrica 2 vezes por mês.	2	2	4	2017-07-09	\N	1	2017-08-19 09:19:53.338071	2017-08-19 09:19:53.338071	1	t
3	Conferir se compraram um aquecedor de ambiente	Conferir se compraram um aquecedor de ambiente da marca Delonghi modelo DCH 5090 de 127V.	2	2	1	2017-07-29	\N	1	2017-08-19 09:20:14.353154	2017-08-19 09:20:14.353154	1	t
4	Verificar se o Backup foi feito automaticamente	\N	2	2	2	2017-07-29	\N	1	2017-08-19 09:20:31.076926	2017-08-19 09:20:31.076926	1	t
5	Verificar se a escala de ferias	Verificar se a escala de ferias dos funcionarios estah pronta e correta.	2	2	5	2016-07-29	\N	1	2017-08-19 09:20:35.159311	2017-08-19 09:20:35.159311	1	t
6	testes Funções DEV 2	Testes Funções Diário	1	2	1	2017-07-01	\N	1	2017-09-02 10:19:32.568313	2017-09-02 10:19:32.568313	1	t
\.


--
-- Name: task_checks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('task_checks_id_seq', 6, true);


--
-- Data for Name: teste; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY teste (id, nome) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY users (id, user_name, password, name, email, mobile_message, cpf, administrator, company_id, created_at, updated_at, updated_by_user_id) FROM stdin;
1	luisfernandoweb	b0c36fd6b5254cbf5665d7e414fd0ee2	Luís Fernando	luisfernandoweb@gmail.com	+5519994230576	13742083880	t	1	2017-08-19 09:19:13.457107	2017-08-19 09:19:13.457107	1
2	fsilvapucci	b0c36fd6b5254cbf5665d7e414fd0ee2	Fernando Silva	fsilvapucci@gmail.com	+553599915534	42231452588	f	1	2017-08-19 09:19:33.252524	2017-08-19 09:19:33.252524	1
3	adm.lftec	b0c36fd6b5254cbf5665d7e414fd0ee2	Luís Fernando LFTEC	adm.lftec@gmail.com	+551981387022	47673425548	f	1	2017-08-19 09:19:33.252524	2017-08-19 09:19:33.252524	1
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('users_id_seq', 3, true);


--
-- Data for Name: weeks_days; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY weeks_days (id, task_check_id, sunday, monday, tuesday, wednesday, thursday, friday, saturday, created_at, updated_at, updated_by_user_id) FROM stdin;
1	1	f	t	t	t	t	t	f	2017-08-19 09:19:39.312127	2017-08-19 09:19:39.312127	1
2	6	t	t	t	t	t	t	t	2017-09-02 10:19:32.568313	2017-09-02 10:19:32.568313	1
\.


--
-- Name: weeks_days_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('weeks_days_id_seq', 2, true);


--
-- Name: auditions auditions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY auditions
    ADD CONSTRAINT auditions_pkey PRIMARY KEY (id);


--
-- Name: audition_tables auditions_tables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY audition_tables
    ADD CONSTRAINT auditions_tables_pkey PRIMARY KEY (table_name);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: days_times days_times_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY days_times
    ADD CONSTRAINT days_times_pkey PRIMARY KEY (id);


--
-- Name: days_times days_times_task_check_id_hour_uk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY days_times
    ADD CONSTRAINT days_times_task_check_id_hour_uk UNIQUE (task_check_id, hour);


--
-- Name: migrations db_version; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY migrations
    ADD CONSTRAINT db_version PRIMARY KEY (db_version);


--
-- Name: execution_queue execution_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY execution_queue
    ADD CONSTRAINT execution_queue_pkey PRIMARY KEY (id);


--
-- Name: months_days months_days_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY months_days
    ADD CONSTRAINT months_days_pkey PRIMARY KEY (id);


--
-- Name: months_days months_days_task_check_id_month_day_uk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY months_days
    ADD CONSTRAINT months_days_task_check_id_month_day_uk UNIQUE (task_check_id, month_day);


--
-- Name: notifications notification_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notification_id PRIMARY KEY (id);


--
-- Name: parameters parameters_category_name_key_name_uk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY parameters
    ADD CONSTRAINT parameters_category_name_key_name_uk UNIQUE (category_name, key_name);


--
-- Name: parameters parameters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY parameters
    ADD CONSTRAINT parameters_pkey PRIMARY KEY (id);


--
-- Name: places places_company_id_name_uk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY places
    ADD CONSTRAINT places_company_id_name_uk UNIQUE (company_id, name);


--
-- Name: places places_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY places
    ADD CONSTRAINT places_pkey PRIMARY KEY (id);


--
-- Name: seeds seed_version; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY seeds
    ADD CONSTRAINT seed_version PRIMARY KEY (seed_version);


--
-- Name: task_checks task_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY task_checks
    ADD CONSTRAINT task_checks_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_user_name_uk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_user_name_uk UNIQUE (user_name);


--
-- Name: weeks_days weeks_days_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY weeks_days
    ADD CONSTRAINT weeks_days_pkey PRIMARY KEY (id);


--
-- Name: weeks_days weeks_days_task_check_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY weeks_days
    ADD CONSTRAINT weeks_days_task_check_id UNIQUE (task_check_id);


--
-- Name: auditions_updated_by_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auditions_updated_by_user_id ON auditions USING btree (updated_by_user_id);


--
-- Name: auditorias_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auditorias_created_at ON auditions USING btree (created_at);


--
-- Name: auditorias_primary_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX auditorias_primary_key ON auditions USING btree (primary_key);


--
-- Name: days_times_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX days_times_idx ON days_times USING btree (task_check_id, hour, minute);


--
-- Name: execucao_fila_next_execution; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX execucao_fila_next_execution ON execution_queue USING btree (next_execution);


--
-- Name: months_days_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX months_days_idx ON months_days USING btree (task_check_id, month_day);


--
-- Name: task_checks_ends_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX task_checks_ends_at ON task_checks USING btree (ends_at);


--
-- Name: task_checks_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX task_checks_name ON task_checks USING btree (name);


--
-- Name: task_checks_starts_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX task_checks_starts_at ON task_checks USING btree (starts_at);


--
-- Name: task_checks_updated_by_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX task_checks_updated_by_user_id ON task_checks USING btree (updated_by_user_id);


--
-- Name: task_checks_user_checker_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX task_checks_user_checker_id ON task_checks USING btree (user_checker_id);


--
-- Name: weeks_days_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX weeks_days_idx ON weeks_days USING btree (task_check_id);


--
-- Name: audition_tables audition_tables_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER audition_tables_audition_trigger AFTER INSERT OR DELETE OR UPDATE ON audition_tables FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: audition_tables audition_tables_before_update_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER audition_tables_before_update_updated_at BEFORE UPDATE ON audition_tables FOR EACH ROW EXECUTE PROCEDURE before_update_updated_at();


--
-- Name: companies companies_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER companies_audition_trigger AFTER INSERT OR DELETE OR UPDATE ON companies FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: companies companies_before_update_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER companies_before_update_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE PROCEDURE before_update_updated_at();


--
-- Name: days_times days_times_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER days_times_audition_trigger AFTER INSERT OR DELETE OR UPDATE ON days_times FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: days_times days_times_update_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER days_times_update_updated_at BEFORE UPDATE ON days_times FOR EACH ROW EXECUTE PROCEDURE before_update_updated_at();


--
-- Name: execution_queue execution_queue_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER execution_queue_audition_trigger AFTER DELETE ON execution_queue FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: execution_queue execution_queue_delete_after_update_executed_sets_true; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER execution_queue_delete_after_update_executed_sets_true AFTER UPDATE ON execution_queue FOR EACH ROW EXECUTE PROCEDURE execution_queue_delete_after_update_executed_sets_true();


--
-- Name: months_days months_days_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER months_days_audition_trigger AFTER INSERT OR DELETE OR UPDATE ON months_days FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: months_days months_days_before_update_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER months_days_before_update_updated_at BEFORE UPDATE ON months_days FOR EACH ROW EXECUTE PROCEDURE before_update_updated_at();


--
-- Name: notifications notifications_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER notifications_audition_trigger AFTER INSERT OR DELETE OR UPDATE ON notifications FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: notifications notifications_before_update_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER notifications_before_update_updated_at BEFORE UPDATE ON notifications FOR EACH ROW EXECUTE PROCEDURE before_update_updated_at();


--
-- Name: parameters parameters_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER parameters_audition_trigger AFTER INSERT OR DELETE OR UPDATE ON parameters FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: parameters parameters_before_update_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER parameters_before_update_updated_at BEFORE UPDATE ON parameters FOR EACH ROW EXECUTE PROCEDURE before_update_updated_at();


--
-- Name: places places_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER places_audition_trigger AFTER INSERT OR DELETE OR UPDATE ON places FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: places places_before_update_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER places_before_update_updated_at BEFORE UPDATE ON places FOR EACH ROW EXECUTE PROCEDURE before_update_updated_at();


--
-- Name: task_checks task_checks_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER task_checks_audition_trigger AFTER INSERT OR DELETE OR UPDATE ON task_checks FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: task_checks task_checks_before_update_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER task_checks_before_update_updated_at BEFORE UPDATE ON task_checks FOR EACH ROW EXECUTE PROCEDURE before_update_updated_at();


--
-- Name: users users_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER users_audition_trigger AFTER INSERT OR DELETE OR UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: users users_before_update_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER users_before_update_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE before_update_updated_at();


--
-- Name: weeks_days weeks_days_audition_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER weeks_days_audition_trigger AFTER INSERT OR DELETE OR UPDATE ON weeks_days FOR EACH ROW EXECUTE PROCEDURE log_it();


--
-- Name: weeks_days weeks_days_before_update_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER weeks_days_before_update_updated_at BEFORE UPDATE ON weeks_days FOR EACH ROW EXECUTE PROCEDURE before_update_updated_at();


--
-- Name: places companies_places_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY places
    ADD CONSTRAINT companies_places_fk FOREIGN KEY (company_id) REFERENCES companies(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: users companies_users_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users
    ADD CONSTRAINT companies_users_fk FOREIGN KEY (company_id) REFERENCES companies(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: notifications parameters_notifications_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT parameters_notifications_fk FOREIGN KEY (notification_type_id) REFERENCES parameters(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: task_checks parameters_periodicity_task_checks_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY task_checks
    ADD CONSTRAINT parameters_periodicity_task_checks_fk FOREIGN KEY (periodicity_id) REFERENCES parameters(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: task_checks places_task_checks_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY task_checks
    ADD CONSTRAINT places_task_checks_fk FOREIGN KEY (place_id) REFERENCES places(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: days_times task_checks_days_times_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY days_times
    ADD CONSTRAINT task_checks_days_times_fk FOREIGN KEY (task_check_id) REFERENCES task_checks(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: execution_queue task_checks_execution_queue_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY execution_queue
    ADD CONSTRAINT task_checks_execution_queue_fk FOREIGN KEY (task_check_id) REFERENCES task_checks(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: months_days task_checks_months_days_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY months_days
    ADD CONSTRAINT task_checks_months_days_fk FOREIGN KEY (task_check_id) REFERENCES task_checks(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: notifications task_checks_notifications_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT task_checks_notifications_fk FOREIGN KEY (task_check_id) REFERENCES task_checks(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: weeks_days task_checks_weeks_days_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY weeks_days
    ADD CONSTRAINT task_checks_weeks_days_fk FOREIGN KEY (task_check_id) REFERENCES task_checks(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: companies users_companies_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY companies
    ADD CONSTRAINT users_companies_fk FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: days_times users_days_times_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY days_times
    ADD CONSTRAINT users_days_times_fk FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: months_days users_months_days_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY months_days
    ADD CONSTRAINT users_months_days_fk FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: notifications users_notifications_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT users_notifications_fk FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: parameters users_periodicities_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY parameters
    ADD CONSTRAINT users_periodicities_fk FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: places users_places_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY places
    ADD CONSTRAINT users_places_fk FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: places users_places_fk1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY places
    ADD CONSTRAINT users_places_fk1 FOREIGN KEY (updated_by_user_id) REFERENCES users(id);


--
-- Name: task_checks users_task_checks_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY task_checks
    ADD CONSTRAINT users_task_checks_fk FOREIGN KEY (user_checker_id) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: task_checks users_task_checks_fk1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY task_checks
    ADD CONSTRAINT users_task_checks_fk1 FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: weeks_days users_weeks_days_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY weeks_days
    ADD CONSTRAINT users_weeks_days_fk FOREIGN KEY (updated_by_user_id) REFERENCES users(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\connect postgres

SET default_transaction_read_only = off;

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.4
-- Dumped by pg_dump version 9.6.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: postgres; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE postgres IS 'default administrative connection database';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- PostgreSQL database dump complete
--

\connect template1

SET default_transaction_read_only = off;

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.4
-- Dumped by pg_dump version 9.6.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: template1; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE template1 IS 'default template for new databases';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database cluster dump complete
--

