FROM crystallang/crystal:1.15.0-alpine
RUN apk update
RUN apk add libjpeg-turbo-dev
RUN apk add libspng-dev
RUN apk add parallel
RUN --mount=type=bind,src=.,dst=/ctx,rw cd /ctx/app/api; shards build api debugger --verbose --no-color -p -s -t --error-trace;  cp /ctx/app/api/bin/api /root/api; cp /ctx/app/api/bin/debugger /root/debugger
CMD /root/api