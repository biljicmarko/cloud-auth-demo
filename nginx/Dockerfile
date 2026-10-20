# OpenResty (nginx + LuaJIT) with lua-resty-openidc for OIDC authentication.
# nginx.conf is not baked in: Ansible renders it and mounts it at runtime,
# so the image contains no client secret.
FROM openresty/openresty:1.31.1.1-alpine-fat

RUN luarocks install lua-resty-openidc 1.9.2-1

COPY html/ /usr/local/openresty/nginx/html/

EXPOSE 80

ENTRYPOINT ["/usr/local/openresty/nginx/sbin/nginx", "-g", "daemon off;"]
