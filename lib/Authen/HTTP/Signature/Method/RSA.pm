package Authen::HTTP::Signature::Method::RSA;

use strict;
use warnings;

use 5.010;

use Moo::Role;
use Crypt::OpenSSL::RSA;
use MIME::Base64 qw(encode_base64 decode_base64);
use Carp qw(confess);

=head1 NAME

Crypt::HTTP::Signature::Method::RSA - Compute digest using asymmetric keys

=cut

our $VERSION = '0.01';

=head1 PURPOSE

This role uses asymmetric RSA keys to compute an HTTP::Signature digest. It implements the
RSA-SHA{1, 256, 512} algorithms.

=head1 ATTRIBUTES

=over 

=item public_key

This holds the public key. It must be a public key instance of L<Crypt::OpenSSL::RSA>. If this
attribute has a value, it is used instead of using the callback to get a key. Required for
signature verification.

=back

=cut

has 'public_key' => (
    is => 'rw',
    isa => sub { confess "Must be a Crypt::OpenSSL::RSA public key" unless ( ref($_[0]) eq "Crypt::OpenSSL::RSA" && ! $_[0]->is_private ) },
    predicate => 'has_public_key',
);

=over

=item public_key_callback

Expects a C<CODE> reference to be used to generate a buffer containing an RSA public key. The key_id attribute's
value will be supplied to the callback as its first parameter. The return value should be a string like

  ----BEGIN RSA PUBLIC KEY----
  ...
  ----END RSA PUBLIC KEY----

=back

=cut

has 'public_key_callback' => (
    is => 'rw',
    isa => sub { confess "'public_key_callback' expects a CODE ref" unless ref($_[0]) eq 'CODE' },
    predicate => 'has_public_key_callback',
    lazy => 1,
);

=over

=item private_key

This holds the private key. It must be a private key instance of L<Crypt::OpenSSL::RSA>. If this
attribute has a value, it is used instead of using the callback to get a key. Required for
signature creation.

=back

=cut

has 'private_key' => (
    is => 'rw',
    isa => sub { confess "Must be a Crypt::OpenSSL::RSA private key" unless ( ref($_[0]) eq "Crypt::OpenSSL::RSA" && $_[0]->is_private ) },
    predicate => 'has_private_key',
);

=over

=item private_key_callback

Expects a C<CODE> reference to be used to generate a buffer containing an RSA private key. The key_id 
attribute's value will be supplied to the callback as its first parameter. The return value should 
be a string like:

  ----BEGIN RSA PRIVATE KEY----
  ...
  ----END RSA PRIVATE KEY----

=back

=cut

has 'private_key_callback' => (
    is => 'rw',
    isa => sub { confess "'private_key_callback' expects a CODE ref" unless ref($_[0]) eq 'CODE' },
    predicate => 'has_private_key_callback',
    lazy => 1,
);

=head1 METHODS

=over

=item sign()

This method uses the C<private_key> to sign the C<signing_string> using the C<algorithm>. The result is
returned and also stored as C<signature>.

Takes an optional L<HTTP::Request> object.  The default input is the C<request> attribute.

If the request does not already have a C<Date> header, this method adds one using the current
GMT system time.

=back

=cut

sub sign {
    my $self = shift;
    my $request = shift || $self->request;

    confess "I don't have a request to sign" unless $request;

    $self->update_date_header();
    $self->update_signing_string();

    confess "How can I sign anything without a signing string?\n" unless $self->has_signing_string;
    confess "How can I sign anything without a private key?\n" unless $self->has_private_key || $self->has_private_key_callback;


    if ( ! $self->has_private_key ) {
        my $key_str = $self->private_key_callback->($self->key_id);
        $self->private_key( Crypt::OpenSSL::RSA->new_private_key($key_str) );
    }

    my $key = $self->private_key;

    confess "I don't have a key!" unless $key;

    $self->_set_digest($key);

    my $s = $key->sign($self->signing_string);

    $self->signature( encode_base64($s) );
}

sub _set_digest {
    my $self = shift;
    my $key = shift;

    for ( $self->algorithm ) {
        when ( /sha1/ ) {
            $key->use_sha1_hash();
        }
        when ( /sha256/ ) {
            $key->use_sha256_hash();
        }
        when ( /sha512/ ) {
            $key->use_sha512_hash();
        }
    }
}

=over

=item validate()

This method validates a signature was generated by a specific private key by using the corresponding
public key.

Returns a boolean.

=back

=cut

sub validate {
    my $self = shift;

    $self->check_skew();

    confess "How can I validate anything without a signature?" unless $self->has_signature;
    confess "How can I validate anything without a signing string?" unless $self->has_signing_string;
    confess "How can I validate anything without a key?" unless ( $self->has_public_key_callback || $self->has_public_key );

    if ( ! $self->has_public_key ) {
        my $pub_str = $self->public_key_callback->($self->key_id);
        $self->public_key ( Crypt::OpenSSL::RSA->new_public_key($pub_str) );
    }

    confess "I don't have a key!" unless $self->has_public_key;

    return $self->public_key->verify($self->signing_string, decode_base64( $self->signature ) );
}

=head1 SEE ALSO

L<Crypt::HTTP::Signature>

=cut

1;