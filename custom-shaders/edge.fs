#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float thresh;

// Output fragment color
out vec4 finalColor;

// NOTE: Add here your custom variables
uniform vec2 resolution = vec2(800, 450);

void main()
{
    float x = 1.0/resolution.x;
    float y = 1.0/resolution.y;

    vec4 horizEdge = vec4(0.0);
    horizEdge -= texture(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y - y))*1.0;
    horizEdge -= texture(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y    ))*2.0;
    horizEdge -= texture(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y + y))*1.0;
    horizEdge += texture(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y - y))*1.0;
    horizEdge += texture(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y    ))*2.0;
    horizEdge += texture(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y + y))*1.0;

    vec4 vertEdge = vec4(0.0);
    vertEdge -= texture(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y - y))*1.0;
    vertEdge -= texture(texture0, vec2(fragTexCoord.x    , fragTexCoord.y - y))*2.0;
    vertEdge -= texture(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y - y))*1.0;
    vertEdge += texture(texture0, vec2(fragTexCoord.x - x, fragTexCoord.y + y))*1.0;
    vertEdge += texture(texture0, vec2(fragTexCoord.x    , fragTexCoord.y + y))*2.0;
    vertEdge += texture(texture0, vec2(fragTexCoord.x + x, fragTexCoord.y + y))*1.0;

    vec3 edge = sqrt((horizEdge.rgb*horizEdge.rgb) + (vertEdge.rgb*vertEdge.rgb));

    float brightness = dot(edge, vec3(0.2126, 0.7152, 0.0722));  // Calculate brightness
    vec3 color = (brightness > thresh) ? vec3(1.0, 1.0, 1.0) : vec3(0.0, 0.0, 0.0);

    finalColor = vec4(color, texture(texture0, fragTexCoord).a);
}
