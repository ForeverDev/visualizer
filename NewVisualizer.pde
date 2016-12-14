import ddf.minim.analysis.*;
import ddf.minim.*;

static final int CIRCLE_RADIUS = 190;
static final int NUM_BG_NODE = 120;
static final float BG_NODE_MIN_RADIUS = 10;
static final float BG_NODE_MAX_RADIUS = 30;
static final String SONG_NAME = "songs/all_we_know.mp3";
static final String SONG_IMAGE = "songs/all_we_know.jpg";

Minim minim;
FFT fft;
AudioPlayer song;
PImage blurred_circle;
PImage album_image;
BackgroundNode[] bg_nodes;

float[][] sound_info, ramp;
float circle_rotate = 0.0;
float avgband = 0.0;
float avgfreq = 0.0;
float maxband = 0.0;
float maxfreq = 0.0;
int last_song_update;

float total_angle = 0.0; /* can't be static in BGNode :( */

class BackgroundNode {
	
	public float angle;
	public float radius;
	public PVector position;

	public BackgroundNode() {
		total_angle += (PI * 2)/NUM_BG_NODE;
		angle = total_angle;
		radius = random(BG_NODE_MIN_RADIUS, BG_NODE_MAX_RADIUS);
		float d = random(max(width, height)/2);
		position = new PVector(width/2 + d*cos(angle), height/2 + d*sin(angle));
	}

	private PVector calculateSpeed() {
		float factor = 1.0 - map(
			BG_NODE_MAX_RADIUS - radius,
			0.0, BG_NODE_MAX_RADIUS - BG_NODE_MIN_RADIUS,
			0.0, 1.0
		) + 0.1;
		return new PVector(
			factor * avgfreq * 0.25 * cos(angle),
			factor * avgfreq * 0.25 * sin(angle)
		);
	}

	public void draw() {
		/* move */
		PVector velocity = calculateSpeed();
		position.x += velocity.x;
		position.y += velocity.y;

		/* check if off screen */
		if (position.x + radius < 0 || position.y + radius < 0
			|| position.x - radius > width || position.y - radius > height) {
			position.x = width/2;
			position.y = height/2;
		}

		noStroke();
		fill(255);
		image(blurred_circle, position.x, position.y, radius, radius); 
	}

};

int sgn(float v) {
	return v < 0 ? -1 : v > 1 ? 1 : 0;
}

void setup() {
	//size(900, 900);
	fullScreen();
	ellipseMode(RADIUS);
	minim = new Minim(this);
	song = minim.loadFile(SONG_NAME);
	if (song == null) {
		println(String.format("couldn't open audio file '%s'", SONG_NAME));
		exit();
	}
	album_image = loadImage(SONG_IMAGE);
	if (album_image == null) {
		println(String.format("couldn't open image file '%s'", SONG_IMAGE));
	}
	fft = new FFT(song.bufferSize(), song.sampleRate());
	sound_info = new float[fft.specSize()][2];
	ramp = new float[fft.specSize()][2];
	bg_nodes = new BackgroundNode[NUM_BG_NODE];
	last_song_update = millis();

	/* create the blurred circle image */
    PGraphics cbuffer = createGraphics(40, 40);
    cbuffer.beginDraw();
    cbuffer.fill(255);
    cbuffer.ellipse(20, 20, 20, 20);
    cbuffer.filter(BLUR, 5);
    cbuffer.endDraw();
    blurred_circle = cbuffer.get();

	/* initialize background nodes */
	for (int i = 0; i < NUM_BG_NODE; i++) {
		bg_nodes[i] = new BackgroundNode();
	}
  
	song.loop();  
	fft.forward(song.mix);
}

void draw() {
  
	if (millis() - last_song_update > 25) {
		last_song_update = millis();
		fft.forward(song.mix);
	}

	int spec = fft.specSize();

	avgfreq = 0.0;
	avgband = 0.0;
	maxfreq = 0.0;
	maxband = 0.0;
	
	/* bars move towards their target (step) pixels/tick */
	final float step = 6.0;
	
	/* calculate values */
	for (int i = 0; i < spec; i++) {
		float band = fft.getBand(i);
		float freq = fft.getFreq(i);
		avgband += band / spec;
		avgfreq += freq / spec;
		sound_info[i][0] = band;
		sound_info[i][1] = freq;
		if (band > maxband) {
			  maxband = band;
		}
		if (freq > maxfreq) {
			  maxfreq = freq;
		}
	}

	for (int i = 0; i < spec; i++) {
		float band = sound_info[i][0];
		float freq = sound_info[i][1];
		
		/* tween the bands 20% towards half of the highest band */
		sound_info[i][0] += ((maxband/2) - sound_info[i][0]) * 0.4;

		if (abs(ramp[i][0] - sound_info[i][0]) < step) {
			ramp[i][0] = sound_info[i][0];
		} else {
			ramp[i][0] += step * -sgn(ramp[i][0] - sound_info[i][0]);
		}
	}
	
	// circle_rotate += maxfreq / 15000.0;

	background(10);

	for (int i = 0; i < NUM_BG_NODE; i++) {
		bg_nodes[i].draw();
	}

	final int repeat = 20;

	noStroke();
	colorMode(HSB, 100);

	int rindex = 0;
	for (int i = 0; i < sound_info.length; i += 4) {
		/* first two bands seem to be pretty choppy.... just skip them for now */
		float band = ramp[rindex % repeat + 2][0];
		float freq = ramp[rindex % repeat + 2][1];
		rindex++;
		pushMatrix();
		resetMatrix();
		translate(width/2, height/2);
		rotate(map(i, 0.0, sound_info.length, 0.0, PI*2.0) + circle_rotate);
		fill(map(i, 0.0, sound_info.length, 0.0, 100.0), 100, 100);
		rect(0, CIRCLE_RADIUS, 5, 6 + band*1.2, 2);
		popMatrix();
	}

	colorMode(RGB, 255);
	fill(255);

	ellipse(width/2, height/2, CIRCLE_RADIUS, CIRCLE_RADIUS);
	
	if (album_image != null) {
		image(album_image, width/2 - 100, height/2 - 100, 200, 200);
	}
  
}

void mousePressed() {
	song.cue(floor(song.length() * map(mouseX, 0.0, width, 0.0, 1.0)));
}
