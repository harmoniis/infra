# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# Use a multi-stage build to keep the final image small

# Stage 1: Build the Rust application
FROM rust:alpine as builder
WORKDIR /usr/src/health_checker
COPY . .

# Install build dependencies
RUN apk add --no-cache build-base

RUN cargo build --release

# Stage 2: Create the final image
FROM alpine:latest
COPY --from=builder /usr/src/health_checker/target/release/health_checker /usr/local/bin/health_checker
EXPOSE 8080
CMD ["health_checker"]
