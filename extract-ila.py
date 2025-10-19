import re

def extract_signals(line):
    match = re.search(r'\.sample_in\(\{(.*?)\}\)', line)
    if not match:
        return []

    signal_str = match.group(1)
    signals = []

    for part in signal_str.split(','):
        part = part.strip()
        if not part:
            continue

        # Match signal with bit range like ovl_0.hsync_shift[3:0]
        range_match = re.match(r'(.+?)\[(\d+):(\d+)\]', part)
        if range_match:
            full_name = f"{range_match.group(1)}[{range_match.group(2)}:{range_match.group(3)}]"
            msb = int(range_match.group(2))
            lsb = int(range_match.group(3))
            width = abs(msb - lsb) + 1
            signals.append(f"{full_name} {width}")
        else:
            signals.append(f"{part} 1")

    return signals

def process_file(input_file, output_file, comment_tag):
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            if comment_tag in line:
                signal_lines = extract_signals(line)
                signal_lines.reverse()
                for sig in signal_lines:
                    outfile.write(sig + '\n')
                break  # stop after first match

# Example usage
process_file('gateware/top.sv', 'ila.sig', 'ILA_FIND_ME')
