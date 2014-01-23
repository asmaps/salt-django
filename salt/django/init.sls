# TODO after initial setup:
  # install gunicorn and psycopg2
  # update create.py and production.py settings
  # run syncdb on server
  # create bridge/configure kvm networking
  # create kvm storage pool
  #
{% set project_name = 'kvmate' %}
{% set git_url = 'https://github.com/asmaps/kvmate.git' %}
{% set server_name = 'kvmate.as-webservices.de' %}
{% set salt_master = 'salt.as-webservices.de' %}
# generate with `pwgen -s 64 1`
{% set django_secret_key = 'O5SDC4EpuVA4jAfRSSym2gCX2viTa2A1DrbCCBaOKrfOk2Mf6DW0WyHaYhulKhkh' %}
{% set postgres_password = 'xee0chie3naMuenee2uw' %}


{{ project_name }}:
  user.present:
    - home: /home/{{ project_name }}
    - shell: /bin/bash
    - create_home: True
    - groups:
      - libvirt
    - remove_groups: False
    - require:
      - pkg: libvirt-bin

  supervisord.running:
    - user: root
    - watch:
      - file: /etc/supervisor/conf.d/{{ project_name }}.conf
    - require:
      - pkg: supervisor
      - file: /etc/supervisor/conf.d/{{ project_name }}.conf

  git.latest:
    - name: {{ git_url }}
    - rev: master
    - user: {{ project_name }}
    - target: /home/{{ project_name }}/src
    - require:
      - user: {{ project_name }}

  module.wait:
    - func: djangomod.collectstatic
    - settings_module: {{ project_name }}.settings
    - watch:
      - git: {{ project_name }}

{{ project_name }}_celery_beat:
  supervisord.running:
    - user: root
    - watch:
      - file: /etc/supervisor/conf.d/{{ project_name }}_celery.conf
    - require:
      - pkg: supervisor
      - pkg: redis-server

{{ project_name }}_celery_worker:
  supervisord.running:
    - user: root
    - watch:
      - file: /etc/supervisor/conf.d/{{ project_name }}_celery.conf
    - require:
      - pkg: supervisor
      - pkg: redis-server

supervisor:
  pkg:
    - installed

postgresql:
  pkg:
    - installed
  postgres_database.present:
    - name: {{ project_name }}
    - owner: {{ project_name }}
    - runas: postgres
  postgres_user.present:
    - name: {{ project_name }}
    - createdb: False
    - createuser: False
    - encrypted: True
    - superuser: False
    - replication: False
    - password: {{ postgres_password }}
    - runas: postgres

/home/{{ project_name }}/src/{{ project_name }}/{{ project_name }}/settings/local_settings.py:
  file.managed:
    - source: 
      - salt://django/local_settings.py.{{ project_name }}
      - salt://django/local_settings.py
    - user: {{ project_name }}
    - group: {{ project_name }}
    - template: jinja
    - context:
      project_name: {{ project_name }}
      postgres_password: {{ postgres_password }}
      secret_key: {{ django_secret_key }}

# FIXME: put file in kvmate specific directory
/home/{{ project_name }}/preseed/post_install.sh:
  file.managed:
    - source: salt://django/post_install.sh
    - user: {{ project_name }}
    - group: {{ project_name }}
    - mode: 644
    - template: jinja
    - context:
      project_name: {{ project_name }}
      salt_master: {{ salt_master }}

/etc/supervisor/conf.d/{{ project_name }}_celery.conf:
  file.managed:
    - source: salt://django/celery_supervisor.conf
    - template: jinja
    - context:
      project_name: {{ project_name }}

pkg-config:
  pkg:
    - installed

redis-server:
  pkg:
    - installed

libvirt-bin:
  pkg:
    - installed

bridge-utils:
  pkg:
    - installed

virtinst:
  pkg:
    - installed

python-virtualenv:
  pkg:
    - installed

python-dev:
  pkg:
    - installed

postgresql-server-dev-all:
  pkg:
    - installed

gcc:
  pkg:
    - installed

libvirt-dev:
  pkg:
    - installed

nginx:
  pkg:
    - installed
  service.running:
    - reload: True
    - watch:
      - file: /etc/nginx/sites-enabled/{{ project_name }}
      - file: /etc/nginx/sites-available/{{ project_name }}

/etc/nginx/sites-available/{{ project_name }}:
  file.managed:
    - source: salt://django/nginx.conf
    - require:
      - pkg: nginx
    - template: jinja
    - context:
      project_name: {{ project_name }}
      server_name: {{ server_name }}

/etc/nginx/sites-enabled/{{ project_name }}:
  file.symlink:
    - target: /etc/nginx/sites-available/{{ project_name }}
    - require:
      - file: /etc/nginx/sites-available/{{ project_name }}

/home/{{ project_name }}/bin/gunicorn_start:
  file.managed:
    - source: salt://django/gunicorn_start
    - user: {{ project_name }}
    - group: {{ project_name }}
    - mode: 755
    - template: jinja
    - context:
      project_name: {{ project_name }}

/etc/supervisor/conf.d/{{ project_name }}.conf:
  file.managed:
    - source: salt://django/supervisor.conf
    - user: root
    - group: root
    - template: jinja
    - context:
      project_name: {{ project_name }}

/home/{{ project_name }}:
  virtualenv.managed:
    - requirements: /home/{{ project_name }}/src/requirements.d/all.txt #FIXME: -r import in production.txt does not work
    - runas: {{ project_name }}
    - cwd: /home/{{ project_name }}/src/requirements.d/
    - require:
      - pkg: python-virtualenv

/home/{{ project_name }}/logs:
  file.directory:
    - user: {{ project_name }}
    - group: {{ project_name }}
    - dir_mode: 777

/home/{{ project_name }}/run:
  file.directory:
    - user: {{ project_name }}
    - group: {{ project_name }}
    - dir_mode: 755

/home/{{ project_name }}/static:
  file.directory:
    - user: {{ project_name }}
    - group: {{ project_name }}
    - dir_mode: 755

/home/{{ project_name }}/preseed:
  file.directory:
    - user: {{ project_name }}
    - group: {{ project_name }}
    - dir_mode: 755
