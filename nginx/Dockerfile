# Use an OpenResty base image as it includes LuaJIT and Nginx
FROM openresty/openresty:alpine-fat

# Install necessary build tools and libraries
RUN apk add --no-cache \
    openssl-dev \
    git \
    gcc \
    make \
    lua-dev \
    luarocks

# Install lua-resty-openidc using Luarocks
RUN luarocks install lua-resty-openidc

# Create Nginx log directory
RUN mkdir -p /var/log/nginx

# Copy custom Nginx configuration
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY html/ /usr/local/openresty/nginx/html/

# Expose port 80 (or 443 if using HTTPS directly on Nginx)
EXPOSE 80

# Command to run Nginx
ENTRYPOINT ["/usr/local/openresty/nginx/sbin/nginx", "-g", "daemon off;"]
