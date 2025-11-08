#!/usr/bin/perl

use strict;
use warnings;

use List::Util qw(shuffle);
use Digest::SHA qw(sha256_hex);
use Time::HiRes qw(usleep);
use POSIX qw(strftime);

# Configuration
my $MAX_BLOCKS = 50;
my $MINING_DIFFICULTY = 4;
my $MIN_SLEEP_MS = 200;
my $MAX_SLEEP_MS = 800;
my $MAX_MINING_ATTEMPTS = 1000000;

# Better random seed
srand(time ^ $$);

# Transaction actions
my @ACTIONS = ("DEPOSIT", "WITHDRAW", "TRANSFER", "EXCHANGE", "LOAN", "PAYMENT");

# Markov chain for transaction sequences
my %MARKOV_CHAIN = (
    "DEPOSIT"  => ["WITHDRAW", "TRANSFER", "EXCHANGE"],
    "WITHDRAW" => ["LOAN", "PAYMENT", "DEPOSIT"],
    "TRANSFER" => ["EXCHANGE", "WITHDRAW", "LOAN"],
    "EXCHANGE" => ["TRANSFER", "PAYMENT", "DEPOSIT"],
    "LOAN"     => ["PAYMENT", "WITHDRAW", "DEPOSIT"],
    "PAYMENT"  => ["EXCHANGE", "TRANSFER", "LOAN"],
);

my @CURRENCIES = ("USD", "EUR", "BTC", "ETH", "XMR", "ZEC");
my @AMOUNTS = map { $_ * 10 } (1..100);

# Security rules
my %HIDDEN_RULES = (
    "ACC12345" => sub { return "BLOCKED" },
    "ACC67890" => sub { return (rand() > 0.8) ? "REVERSED" : "" },
    "XMR"      => sub { return (rand() > 0.7) ? "SUSPICIOUS" : "" },
);

# Global variables
my @blockchain;
my $previous_hash = "GENESIS";
my $block_count = 0;

sub generate_account {
    return "ACC" . sprintf("%05d", int(rand(99999)));
}

sub mine_block {
    my ($data, $difficulty) = @_;
    my $nonce = 0;
    my $hash;
    my $target = "0" x $difficulty;
    
    while ($nonce < $MAX_MINING_ATTEMPTS) {
        $hash = sha256_hex($data . $nonce);
        if (substr($hash, 0, $difficulty) eq $target) {
            return ($hash, $nonce);
        }
        $nonce++;
    }
    
    die "Mining failed after $MAX_MINING_ATTEMPTS attempts";
}

sub validate_blockchain {
    my ($difficulty) = @_;
    my $prev_hash = "GENESIS";
    
    for my $i (0..$#blockchain) {
        my $block = $blockchain[$i];
        
        # Check previous hash linkage
        if ($block->{previous_hash} ne $prev_hash) {
            print "Blockchain invalid at block $i: Previous hash mismatch\n";
            return 0;
        }
        
        # Verify block hash
        my $calculated_hash = sha256_hex($block->{transaction} . $block->{nonce});
        if ($calculated_hash ne $block->{hash}) {
            print "Blockchain invalid at block $i: Hash verification failed\n";
            return 0;
        }
        
        # Check mining difficulty
        my $target = "0" x $difficulty;
        if (substr($block->{hash}, 0, $difficulty) ne $target) {
            print "Blockchain invalid at block $i: Difficulty requirement not met\n";
            return 0;
        }
        
        $prev_hash = $block->{hash};
    }
    
    return 1;
}

# Parse command line arguments
my %args = (
    max_blocks => $MAX_BLOCKS,
    difficulty => $MINING_DIFFICULTY,
);

for my $i (0..$#ARGV) {
    if ($ARGV[$i] eq '--blocks' && $i < $#ARGV) {
        $args{max_blocks} = $ARGV[++$i];
    }
    elsif ($ARGV[$i] eq '--difficulty' && $i < $#ARGV) {
        $args{difficulty} = $ARGV[++$i];
    }
    elsif ($ARGV[$i] eq '--help') {
        print "Usage: $0 [options]\n";
        print "Options:\n";
        print "    --blocks N      Number of blocks to generate (default: $MAX_BLOCKS)\n";
        print "    --difficulty N  Mining difficulty (default: $MINING_DIFFICULTY)\n";
        print "    --help         Show this help message\n";
        exit 0;
    }
}

# Validate arguments
if ($args{max_blocks} !~ /^\d+$/ || $args{max_blocks} < 1) {
    die "Invalid number of blocks: $args{max_blocks}";
}
if ($args{difficulty} !~ /^\d+$/ || $args{difficulty} < 1 || $args{difficulty} > 6) {
    die "Invalid difficulty: $args{difficulty} (must be 1-6)";
}

print "Starting blockchain simulation...\n";
print "Max blocks: $args{max_blocks}, Difficulty: $args{difficulty}\n";
print "=" x 50 . "\n";

my $current_action = $ACTIONS[int(rand(scalar @ACTIONS))];

while ($block_count < $args{max_blocks}) {
    # Get next action from Markov chain
    my $next_actions = $MARKOV_CHAIN{$current_action};
    $current_action = $next_actions->[int(rand(scalar @$next_actions))];
    
    # Generate accounts
    my $account_from = generate_account();
    my $account_to = generate_account();
    
    while ($account_from eq $account_to) {
        $account_to = generate_account();
    }
    
    # Generate transaction details
    my $currency = $CURRENCIES[int(rand(scalar @CURRENCIES))];
    my $amount = $AMOUNTS[int(rand(scalar @AMOUNTS))];
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    
    # Apply security rules
    my $rule_result = "";
    if (exists $HIDDEN_RULES{$account_from}) {
        $rule_result = $HIDDEN_RULES{$account_from}->();
    }
    if (exists $HIDDEN_RULES{$currency}) {
        $rule_result = $HIDDEN_RULES{$currency}->();
    }
    
    # Handle rule results
    if ($rule_result eq "BLOCKED") {
        print "[RULE] Transaction BLOCKED: $account_from\n";
        print "-" x 50 . "\n";
        next;
    } elsif ($rule_result eq "SUSPICIOUS") {
        print "[RULE] Transaction FLAGGED as SUSPICIOUS: $currency\n";
    } elsif ($rule_result eq "REVERSED") {
        if (@blockchain) {
            my $last_block = pop @blockchain;
            print "[RULE] REVERSING BLOCK: $last_block->{hash}\n";
            $previous_hash = $last_block->{previous_hash};
            $block_count--;
            print "-" x 50 . "\n";
        }
        next;
    }
    
    # Create transaction string
    my $transaction = "$timestamp | $current_action | $account_from -> $account_to | $amount $currency | PrevHash: $previous_hash";
    
    # Mine the block
    print "Mining block (difficulty: $args{difficulty})...\n";
    my ($block_hash, $nonce) = mine_block($transaction, $args{difficulty});
    
    # Create block
    my %block = (
        timestamp => $timestamp,
        transaction => $transaction,
        nonce => $nonce,
        hash => $block_hash,
        previous_hash => $previous_hash,
    );
    
    # Add to blockchain
    push @blockchain, \%block;
    $previous_hash = $block_hash;
    $block_count++;
    
    # Display block information
    print "BLOCK MINED:\n";
    print "Timestamp  : $block{timestamp}\n";
    print "Transaction: $block{transaction}\n";
    print "Nonce      : $block{nonce}\n";
    print "Hash       : $block{hash}\n";
    print "Block Count: $block_count/$args{max_blocks}\n";
    
    if ($rule_result) {
        print "Flags      : $rule_result\n";
    }
    
    print "-" x 50 . "\n";
    
    # Random delay
    my $sleep_time = int(rand($MAX_SLEEP_MS - $MIN_SLEEP_MS)) + $MIN_SLEEP_MS;
    usleep($sleep_time * 1000);
}

# Validate final blockchain
print "\nValidating blockchain...\n";
if (validate_blockchain($args{difficulty})) {
    print "Blockchain validation: PASSED\n";
} else {
    print "Blockchain validation: FAILED\n";
}

print "Blockchain simulation completed with $block_count blocks.\n";
print "Final chain length: " . scalar(@blockchain) . " blocks\n";
print "Last hash: " . substr($previous_hash, 0, 16) . "...\n";

exit 0;
