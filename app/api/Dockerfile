FROM crystallang/crystal:1.15.0-alpine
WORKDIR /root
COPY . . 
RUN apk update
RUN apk add libjpeg-turbo-dev
RUN apk add libspng-dev
RUN shards build api --no-debug --verbose --no-color -p -s -t --error-trace
CMD ["/root/bin/api"]