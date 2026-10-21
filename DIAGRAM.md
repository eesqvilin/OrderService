## CI Diagram

```mermaid
flowchart LR

subgraph J1[Format, Build and Test]
    S1[Format Check] --> S2[Build]
    S2 -->S3[Test]
    S3 --> S4[Check Vulnerable Packages]
end

subgraph J2[Docker Build and Scan]
    SB1[Build Image] --> SB2[Scan Image]
    SB2 --> SB3[Login to GHCR]
    SB3 --> SB4[Push Image to GHCR]
end

subgraph J3[Deploy]
    SC1[Pull Image] --> SC2[Run Container]
    SC2 --> [Verify Container Version]
end

J1 --->|needs: format-build-and-test| J2
J2 --->|needs: docker-build-and-scan| J3
```