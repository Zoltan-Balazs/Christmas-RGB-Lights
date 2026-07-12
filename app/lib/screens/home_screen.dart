import 'package:flutter/material.dart';

import '../ble/light_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = LightController();

  int _red = 255;
  int _green = 0;
  int _blue = 0;
  bool _power = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _currentColor => Color.fromARGB(255, _red, _green, _blue);

  Future<void> _connect() async {
    setState(() => _error = null);
    try {
      await _controller.connect();
    } catch (e) {
      setState(() => _error = 'Could not connect: $e');
    }
  }

  Future<void> _sendColor() async {
    try {
      await _controller.sendSteadyColor(red: _red, green: _green, blue: _blue);
    } catch (e) {
      setState(() => _error = 'Failed to send color: $e');
    }
  }

  Future<void> _togglePower(bool on) async {
    setState(() => _power = on);
    try {
      await _controller.sendPower(on);
    } catch (e) {
      setState(() => _error = 'Failed to send power state: $e');
    }
  }

  Widget _channelSlider(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 16, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 36, child: Text('$value')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Christmas Lights')),
      body: StreamBuilder<LightConnectionState>(
        stream: _controller.stateStream,
        initialData: _controller.state,
        builder: (context, snapshot) {
          final state = snapshot.data ?? LightConnectionState.disconnected;
          final connected = state == LightConnectionState.connected;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_statusLabel(state)),
                    if (!connected)
                      FilledButton(
                        onPressed: state == LightConnectionState.scanning ||
                                state == LightConnectionState.connecting
                            ? null
                            : _connect,
                        child: const Text('Connect'),
                      )
                    else
                      OutlinedButton(
                        onPressed: _controller.disconnect,
                        child: const Text('Disconnect'),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
                const SizedBox(height: 16),
                _channelSlider('R', _red, (v) => setState(() => _red = v)),
                _channelSlider('G', _green, (v) => setState(() => _green = v)),
                _channelSlider('B', _blue, (v) => setState(() => _blue = v)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: connected ? _sendColor : null,
                  child: const Text('Send color'),
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Power'),
                  value: _power,
                  onChanged: connected ? _togglePower : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(LightConnectionState state) {
    switch (state) {
      case LightConnectionState.disconnected:
        return 'Disconnected';
      case LightConnectionState.scanning:
        return 'Scanning…';
      case LightConnectionState.connecting:
        return 'Connecting…';
      case LightConnectionState.connected:
        return 'Connected';
    }
  }
}
