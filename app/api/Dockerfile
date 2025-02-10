FROM crystallang/crystal:1.15.0-alpine
RUN apk update
RUN apk add libjpeg-turbo-dev
RUN apk add libspng-dev
WORKDIR /root
COPY . .
WORKDIR /root
RUN ls
WORKDIR /root/app/api
RUN shards build api --verbose --no-color -p -s -t --error-trace
CMD ["/root/app/api/bin/api"]