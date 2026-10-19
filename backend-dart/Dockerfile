FROM dart:stable
WORKDIR /app
COPY . .
RUN dart pub get
ARG APP
ENV APP=$APP
CMD ["sh", "-c", "dart run apps/${APP}/bin/main.dart"]
