use clap::Parser;

/// Test arguments.
#[derive(Parser, Debug)]
#[command(author, version, about, long_about=None)]
struct Args {
    /// Test argument
    #[arg(short, long)]
    name: String,
}

fn main() {
    let args: Args = Args::parse();
    let name: String = String::from(args.name);
    println!("Hello, {}!", name);
}
