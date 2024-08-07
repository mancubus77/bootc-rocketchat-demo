FROM quay.io/mancubus77/bootc:base

#install the lamp components
RUN dnf install -y insights-client httpd mariadb mariadb-server php-fpm php-mysqlnd && dnf clean all

#start the services automatically on boot
RUN systemctl enable httpd mariadb php-fpm

#create an awe inspiring home page!
RUN echo '<h1 style="text-align:center;">Welcome to image mode for RHEL</h1> <?php phpinfo(); ?>' >> /var/www/html/index.php
