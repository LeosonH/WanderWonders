begin;

alter role authenticated set statement_timeout = '5s';
alter role service_role set statement_timeout = '5s';

notify pgrst, 'reload config';

commit;
