package com.airbnb.android.react.maps;

import android.content.Context;

import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.model.TileOverlay;
import com.google.android.gms.maps.model.TileOverlayOptions;
import com.google.android.gms.maps.model.TileProvider;
import com.google.android.gms.maps.model.UrlTileProvider;

import java.net.MalformedURLException;
import java.net.URL;

public class AirMapWMSTile extends AirMapUrlTile {
  private static final double[] mapBound = {-20037508.34789244, 20037508.34789244};
  private static final double FULL = 20037508.34789244 * 2;

  class AIRMapGSUrlTileProvider extends AirMapTileProvider {

    public AIRMapGSUrlTileProvider(int tileSizet, String urlTemplate, 
    int maximumZ, int maximumNativeZ, int minimumZ, String tileCachePath, 
    int tileCacheMaxAge, boolean offlineMode, Context context) {
      super(tileSizet, false, urlTemplate, maximumZ, maximumNativeZ, minimumZ, false,
        tileCachePath, tileCacheMaxAge, offlineMode, context);
    }

    @Override
    protected URL getTileUrl(int x, int y, int zoom) {
      if(AirMapWMSTile.this.maximumZ > 0 && zoom > maximumZ) {
          return null;
      }

      if(AirMapWMSTile.this.minimumZ > 0 && zoom < minimumZ) {
          return null;
      }

      double[] bb = getBoundingBox(x, y, zoom);
      String s = this.urlTemplate
          .replace("{minX}", Double.toString(bb[0]))
          .replace("{minY}", Double.toString(bb[1]))
          .replace("{maxX}", Double.toString(bb[2]))
          .replace("{maxY}", Double.toString(bb[3]))
          .replace("{width}", Integer.toString(this.tileSize))
          .replace("{height}", Integer.toString(this.tileSize));
      URL url = null;

      try {
        url = new URL(s);
      } catch (MalformedURLException e) {
        throw new AssertionError(e);
      }
      return url;
    }

    private double[] getBoundingBox(int x, int y, int zoom) {
      double tile = FULL / Math.pow(2, zoom);
      return new double[]{
              mapBound[0] + x * tile,
              mapBound[1] - (y + 1) * tile,
              mapBound[0] + (x + 1) * tile,
              mapBound[1] - y * tile
      };
    }
  }

  private AIRMapGSUrlTileProvider tileProvider;

  public AirMapWMSTile(Context context) {
    super(context);
  }

  @Override
  protected TileOverlayOptions createTileOverlayOptions() {
    TileOverlayOptions options = new TileOverlayOptions();
    options.zIndex(zIndex);
    options.transparency(1 - this.opacity);
    this.tileProvider = new AIRMapGSUrlTileProvider((int)this.tileSize, this.urlTemplate, 
      (int)this.maximumZ, (int)this.maximumNativeZ, (int)this.minimumZ, this.tileCachePath, 
      (int)this.tileCacheMaxAge, this.offlineMode, this.context);
    options.tileProvider(this.tileProvider);
    return options;
  }
}
