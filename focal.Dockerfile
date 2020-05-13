# syntax=docker/dockerfile:experimental

# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/experimental.md
# Example: 
# export DOCKER_BUILDKIT=1
# docker build \
#    --tag spark/kimera_vio:focal \
#    --file focal.Dockerfile .

ARG FROM_IMAGE=osrf/ros2:nightly
ARG UNDERLAY_WS=/opt/underlay_ws
ARG KIMERA_WS=/opt/kimera_ws

# multi-stage for caching
FROM $FROM_IMAGE AS cacher

# clone underlay source
ARG UNDERLAY_WS
WORKDIR $UNDERLAY_WS/src
COPY ./install/underlay.repos ../
RUN vcs import ./ < ../underlay.repos && \
    find ./ -name ".git" | xargs rm -rf

# copy kimera source
ARG KIMERA_WS
WORKDIR $KIMERA_WS/src
COPY ./ ./MIT-SPARK/Kimera-VIO
COPY ./install/kimera.repos ../
RUN vcs import ./ < ../kimera.repos && \
    find ./ -name ".git" | xargs rm -rf

# copy manifests for caching
WORKDIR /opt
RUN mkdir -p /tmp/opt && \
    find ./ -name "package.xml" | \
      xargs cp --parents -t /tmp/opt && \
    find ./ -name "COLCON_IGNORE" | \
      xargs cp --parents -t /tmp/opt || true

# multi-stage for building
FROM $FROM_IMAGE AS builder

# edit apt for caching
RUN cp /etc/apt/apt.conf.d/docker-clean /etc/apt/ && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' \
      > /etc/apt/apt.conf.d/docker-clean

# install CI dependencies
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -q -y \
      ccache \
      lcov \
      xvfb

# install underlay dependencies
ARG UNDERLAY_WS
WORKDIR $UNDERLAY_WS
COPY --from=cacher /tmp/$UNDERLAY_WS/src ./src
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    . /opt/ros/$ROS_DISTRO/setup.sh && \
    apt-get update && rosdep install -q -y \
      --from-paths src \
      --ignore-src

# build underlay source
COPY --from=cacher $UNDERLAY_WS/src ./src
ARG UNDERLAY_MIXINS="release ccache"
RUN --mount=type=cache,target=/root/.ccache \
    . /opt/ros/$ROS_DISTRO/setup.sh && \
    colcon build \
      --symlink-install \
      --mixin $UNDERLAY_MIXINS \
      --cmake-args \
        --no-warn-unused-cli \
        -DGTSAM_BUILD_TESTS=OFF \
        -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
        -DGTSAM_BUILD_UNSTABLE=ON \
        -DGTSAM_POSE3_EXPMAP=ON \
        -DGTSAM_ROT3_EXPMAP=ON
      # --event-handlers console_direct+

# install kimera dependencies
ARG KIMERA_WS
WORKDIR $KIMERA_WS
COPY --from=cacher /tmp/$KIMERA_WS/src ./src
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    . $UNDERLAY_WS/install/setup.sh && \
    apt-get update && rosdep install -q -y \
      --from-paths src \
        $UNDERLAY_WS/src \
      --ignore-src

# build kimera source
COPY --from=cacher $KIMERA_WS/src ./src
ARG KIMERA_MIXINS="release ccache"
RUN --mount=type=cache,target=/root/.ccache \
    . $UNDERLAY_WS/install/setup.sh && \
    colcon build \
      --symlink-install \
      --mixin $KIMERA_MIXINS \
      --cmake-args \
        --no-warn-unused-cli \
        -DCMAKE_CXX_FLAGS="\
          -Wno-comment \
          -Wno-parentheses \
          -Wno-reorder \
          -Wno-sign-compare \
          -Wno-unused-but-set-variable \
          -Wno-unused-function \
          -Wno-unused-parameter \
          -Wno-unused-value \
          -Wno-unused-variable"
      # --event-handlers console_direct+

# restore apt for docker
RUN mv /etc/apt/docker-clean /etc/apt/apt.conf.d/ && \
    rm -rf /var/lib/apt/lists/

# source wrapper from entrypoint
ENV KIMERA_WS $KIMERA_WS
RUN sed --in-place \
      's|^source .*|source "$KIMERA_WS/install/setup.bash"|' \
      /ros_entrypoint.sh
