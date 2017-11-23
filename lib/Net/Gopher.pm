unit module Net::Gopher;
use URI;

class Net::Gopher::Entry {
    has $.type;
    has $.display-string;
    has $.selector;
    has $.hostname;
    has $.port;

    method gist {
        if $.type eq 'i' {
            return $.display-string;
        } else {
            my $type = do given $.type {
                when '0' { '[TEXT FILE]' }
                when '1' { '[DIRECTORY]' }
                default  { "[    $.type    ]" }
            };
            return "$type $.display-string ($.hostname:$.port$.selector)";
        }
    }
}

class Net::Gopher::Response {
    has @.entries;

    method gist {
        @.entries».gist.join("\n");
    }
}

grammar Net::Gopher::Response::Grammar {
    token TOP {
        <line>+ %% [\r?\n]
        ['.'\r?\n]?
    }

    token line {
        <type=.alnum>
        <display-string=.unasciistr> \t
        <selector=.unasciistr> \t
        <hostname=.unasciistr> \t
        <port>
    }

    token unasciistr {
        <unascii>*
    }

    token unascii {
        . && <-[\t\n]>
    }

    token port {
        \d+
    }
}

class Net::Gopher::Response::Actions {
    method TOP($/) {
        make Net::Gopher::Response.new(
            entries => $<line>».made
        );
    }

    method line($/) {
        make Net::Gopher::Entry.new(
            type           => ~$<type>,
            display-string => ~$<display-string>,
            selector       => ~$<selector>,
            hostname       => ~$<hostname>,
            port           => Int(~$<port>),
        );
    }

}

sub get($address) is export {
    my $uri = URI.new($address);
    my $conn = IO::Socket::INET.new(
        host => $uri.host,
        port => $uri.port,
    );
    $conn.print($uri.path ~ "\n");
    my $resp = '';
    loop {
        my $line = $conn.recv;
        last unless $line;
        $resp ~= $line;
    }
    $resp = Net::Gopher::Response::Grammar.parse(
        $resp,
        :actions(Net::Gopher::Response::Actions)
    ).made;
    return $resp;
}
