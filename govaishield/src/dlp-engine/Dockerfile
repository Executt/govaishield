FROM python:3.12-slim AS build
WORKDIR /app
COPY pyproject.toml ./
COPY src ./src
RUN pip install --no-cache-dir --user .

FROM python:3.12-slim
RUN useradd -r -u 10001 app
COPY --from=build /root/.local /home/app/.local
COPY --from=build /app /app
ENV PATH=/home/app/.local/bin:$PATH PYTHONDONTWRITEBYTECODE=1
USER 10001
WORKDIR /app
EXPOSE 8081
CMD ["uvicorn","dlp_engine.api:app","--host","0.0.0.0","--port","8081"]
