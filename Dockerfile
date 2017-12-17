FROM python:2

# Prep the environment
RUN apt-get update && apt-get -y install \
  build-essential \
  python-dev \
  python-pip \
  python-setuptools \
  libxml2-dev \
  libxslt1-dev \
  zlib1g-dev \
  texlive-latex-recommended \
  texlive-fonts-recommended \
  texlive-latex-extra \
  doxygen \
  dvipng \
  graphviz \
  nginx \
  vim \
  git \
  redis-server

# Install readthedocs (bits as of Dec 15 2015)
RUN mkdir /www
WORKDIR /www

RUN git clone https://github.com/rtfd/readthedocs.org.git
COPY ./files/tasksrecommonmark.patch ./tasksrecommonmark.patch

WORKDIR /www/readthedocs.org



# Install the required Python packages
RUN pip install -r requirements.txt

# Install a higher version of requests to fix an SSL issue
RUN pip install requests==2.6.0

# Override the default settings
COPY ./files/local_settings.py ./readthedocs/settings/local_settings.py
COPY ./files/tasksrecommonmark.patch ./tasksrecommonmark.patch

# Patch tasks.py to use newer recommonmark

# Deploy the database
RUN python ./manage.py migrate

# Create a super user
RUN python manage.py createsuperuser

# Copy static files
RUN python ./manage.py collectstatic --noinput

# Load test data
RUN python ./manage.py loaddata test_data

# # Install gunicorn web server
RUN pip install gunicorn
RUN pip install setproctitle

# Set up the gunicorn startup script
COPY ./files/gunicorn_start.sh ./gunicorn_start.sh
RUN chmod u+x ./gunicorn_start.sh

# Install supervisord
RUN pip install supervisor
ADD files/supervisord.conf /etc/supervisord.conf

VOLUME /www/readthedocs.org

ENV RTD_PRODUCTION_DOMAIN 'localhost:8080'

# Set up nginx
COPY ./files/readthedocs.nginx.conf /etc/nginx/sites-available/readthedocs
RUN ln -s /etc/nginx/sites-available/readthedocs /etc/nginx/sites-enabled/readthedocs

# Clean Up Apt

RUN apt-get autoremove -y
CMD ["bash", "gunicorn_start.sh"]
