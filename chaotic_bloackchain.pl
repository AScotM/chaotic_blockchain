#!/usr/bin/perl
use strict;
use warnings;
use List::Util qw(shuffle);
use Digest::SHA qw(sha256_hex);
use Time::HiRes qw(usleep);
use POSIX qw(strftime);

# --- Transaction Base Data ---
my @actions = ("DEPOSIT", "WITHDRAW", "TRANSFER", "EXCHANGE", "LOAN", "PAYMENT");
my @currencies = ("USD", "EUR", "BTC", "ETH", "XMR", "ZEC");
my @accounts = map { "ACC" . int(rand(99999)) } (1..10);
my @amounts = map { $_ * 10 } (1..100);

# --- Markov Chain for Transaction Types ---
my %markov_chain = (
    "DEPOSIT"  => ["WITHDRAW", "TRANSFER", "EXCHANGE"],
    "WITHDRAW" => ["LOAN", "PAYMENT", "DEPOSIT"],
    "TRANSFER" => ["EXCHANGE", "WITHDRAW", "LOAN"],
    "EXCHANGE" => ["TRANSFER", "PAYMENT", "DEPOSIT"],
    "LOAN"     => ["PAYMENT", "WITHDRAW", "DEPOSIT"],
    "PAYMENT"  => ["EXCHANGE", "TRANSFER", "LOAN"],
);

# --- Hidden Rules (Fraud Detection, Self-Corrections) ---
my %hidden_rules = (
    "ACC12345" => sub { return "BLOCKED"; },
    "ACC67890" => sub { return (rand() > 0.8) ? "REVERSED" : ""; },
    "XMR"      => sub { return (rand() > 0.7) ? "SUSPICIOUS" : ""; },
);

# --- Blockchain Data ---
my @blockchain;
my $previous_hash = "GENESIS";  # First block has no previous hash

# --- Chaotic Proof-of-Work Function ---
sub mine_block {
    my ($data, $difficulty) = @_;
    my $nonce = 0;
    my $hash;
    do {
        $nonce++;
        $hash = sha256_hex($data . $nonce);
    } while (substr($hash, 0, $difficulty) ne "0" x $difficulty);
    return ($hash, $nonce);
}

# --- Infinite Blockchain Generation ---
my $current_action = (shuffle @actions)[0];

while (1) {
    # Choose next transaction type
    my $next_actions = $markov_chain{$current_action};
    $current_action = (shuffle @$next_actions)[0];

    # Generate transaction details
    my $account_from = (shuffle @accounts)[0];
    my $account_to = (shuffle @accounts)[1];
    my $currency = (shuffle @currencies)[0];
    my $amount = (shuffle @amounts)[0];
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);

    # Check hidden rules
    my $rule_result = "";
    $rule_result = $hidden_rules{$account_from}->() if exists $hidden_rules{$account_from};
    $rule_result = $hidden_rules{$currency}->() if exists $hidden_rules{$currency};

    if ($rule_result eq "BLOCKED") {
        print "[RULE] Transaction BLOCKED: $account_from\n";
        next;
    } elsif ($rule_result eq "SUSPICIOUS") {
        print "[RULE] Transaction FLAGGED as SUSPICIOUS: $currency\n";
    } elsif ($rule_result eq "REVERSED") {
        if (@blockchain) {
            my $last_block = pop @blockchain;
            print "[RULE] REVERSING BLOCK: $last_block->{hash}\n";
            $previous_hash = $last_block->{previous_hash};
        }
        next;
    }

    # Create transaction data
    my $transaction = "$timestamp | $current_action | $account_from -> $account_to | $amount $currency | PrevHash: $previous_hash";

    # Proof-of-Work (difficulty = 4)
    print "Mining block...\n";
    my ($block_hash, $nonce) = mine_block($transaction, 4);

    # Store block
    my %block = (
        timestamp => $timestamp,
        transaction => $transaction,
        nonce => $nonce,
        hash => $block_hash,
        previous_hash => $previous_hash,
    );

    push @blockchain, \%block;
    $previous_hash = $block_hash;

    # Output block data
    print "BLOCK MINED:\n";
    print "Timestamp  : $block{timestamp}\n";
    print "Transaction: $block{transaction}\n";
    print "Nonce      : $block{nonce}\n";
    print "Hash       : $block{hash}\n";
    print "--------------------------------------\n";

    # Random delay
    usleep(int(rand(800000) + 200000));
}

