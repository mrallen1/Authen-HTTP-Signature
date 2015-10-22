package Authen::HTTP::Signature::Method::RSA;

use strict;
use warnings;

use 5.010;

use Moo;
use Crypt::OpenSSL::RSA;
use MIME::Base64 qw(encode_base64 decode_base64);
use Carp qw(confess);

=head1 NAME

Crypt::HTTP::Signature::Method::RSA - Compute digest using asymmetric keys

=cut

our $VERSION = '0.02';

=head1 PURPOSE

This class uses asymmetric RSA keys to compute a HTTP signature digest. It implements the
RSA-SHA{1, 256, 512} algorithms.

=head1 ATTRIBUTES

=over 

=item key

Holds the key data.  This should be a string that L<Crypt::OpenSSL::RSA> can instantiate into
a private or public key.  

If the operation is C<sign()>, then this attribute must hold a private key. 
In other words, the string this attribute holds should start with

  -----BEGIN RSA PRIVATE KEY-----


If the operation is C<verify()>, then this attribute must hold a public key. 
In other words, the string this attribute holds should start with

  -----BEGIN PUBLIC KEY-----

=back

=cut

has 'key' => (
    is => 'ro',
    required => 1,
);

=over

=item data

Holds the data to be signed or verified. This is typically the C<signing_string> attribute 
from L<Authen::HTTP::Signature>. Read-only. Required.

=back

=cut

has 'data' => (
    is => 'ro',
    required => 1,
);

=over

=item hash

Digest algorithm. Read-only. Required.

=back

=cut

has 'hash' => (
    is => 'ro',
    required => 1,
);

=head1 METHODS

=over

=item sign()

Signs C<data> using C<key>. 

Returns a base 64 encoded signature.

=back

=cut

sub sign {
    my $self = shift;

    my $key = Crypt::OpenSSL::RSA->new_private_key($self->key);
    confess "I don't have a key!" unless $key;

    $self->_set_digest($key);

    my $s = $key->sign($self->data);

    # pass empty string as second arg to prevent line breaks in stream
    return encode_base64($s, "");
}

sub _set_digest {
    my $self = shift;
    my $key = shift;

    if ( $self->hash =~ /sha1/ ) {
        $key->use_sha1_hash();
    }
    elsif ( $self->hash =~ /sha256/ ) {
        $key->use_sha256_hash();
    }
    elsif ( $self->hash =~ /sha512/ ) {
        $key->use_sha512_hash();
    }
}

=over

=item verify()

This method validates a signature was generated by a specific private key by using the corresponding
public key.

Takes a Base64 encoded signature string as input.

Returns a boolean.

=back

=cut

sub verify {
    my $self = shift;
    my $signature = shift;

    confess "I don't have a signature to verify!" unless $signature;

    my $key = Crypt::OpenSSL::RSA->new_public_key($self->key);
    confess "I don't have a key!" unless $key;

    $self->_set_digest($key);

    return $key->verify($self->data, decode_base64( $signature ));
}

=head1 SEE ALSO

L<Authen::HTTP::Signature>

=cut

1;
