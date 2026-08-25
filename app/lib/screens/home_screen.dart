import 'package:flutter/material.dart';

import '../ble/light_controller.dart';
import '../ble/packet.dart';

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

  UniColorEffect _uniEffect = UniColorEffect.inWaves;
  int _uniColorIndex = 1;
  MultiColorEffect _multiEffect = MultiColorEffect.fade;
  int _speed = 3;

  bool _slot1Enabled = false;
  TimeOfDay _slot1On = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _slot1Off = const TimeOfDay(hour: 23, minute: 0);
  bool _slot2Enabled = false;
  TimeOfDay _slot2On = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _slot2Off = const TimeOfDay(hour: 8, minute: 0);

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

  Future<void> _sendColor() => _run(
        () => _controller.sendSteadyColor(red: _red, green: _green, blue: _blue),
        'Failed to send color',
      );

  Future<void> _togglePower(bool on) {
    setState(() => _power = on);
    return _run(() => _controller.sendPower(on), 'Failed to send power state');
  }

  Future<void> _run(Future<void> Function() action, String failureMessage) async {
    try {
      await action();
    } catch (e) {
      setState(() => _error = '$failureMessage: $e');
    }
  }

  Future<void> _syncTime() =>
      _run(_controller.sendSyncTime, 'Failed to sync time');

  Future<void> _applyUniColor() => _run(
        () => _controller.sendUniColorEffect(
          effect: _uniEffect,
          colorIndex: _uniColorIndex,
        ),
        'Failed to apply effect',
      );

  Future<void> _applyMultiColor() => _run(
        () => _controller.sendMultiColorEffect(_multiEffect),
        'Failed to apply effect',
      );

  Future<void> _applySpeed(int level) {
    setState(() => _speed = level);
    return _run(() => _controller.sendSpeed(level), 'Failed to set speed');
  }

  Future<void> _applyTimer() => _run(
        () => _controller.sendTimer(
          TimerSlot(
            enabled: _slot1Enabled,
            onHour: _slot1On.hour,
            onMinute: _slot1On.minute,
            offHour: _slot1Off.hour,
            offMinute: _slot1Off.minute,
          ),
          TimerSlot(
            enabled: _slot2Enabled,
            onHour: _slot2On.hour,
            onMinute: _slot2On.minute,
            offHour: _slot2Off.hour,
            offMinute: _slot2Off.minute,
          ),
        ),
        'Failed to save timer',
      );

  Future<void> _pickTime(TimeOfDay initial, ValueChanged<TimeOfDay> onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onPicked(picked);
  }

  String _formatEnumLabel(String name) {
    final withSpaces = name.replaceAllMapped(
      RegExp(r'(?<=[a-z])(?=[A-Z])'),
      (m) => ' ',
    );
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
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
      appBar: AppBar(title: const Text('Actuel RGB Light')),
      body: StreamBuilder<LightConnectionState>(
        stream: _controller.stateStream,
        initialData: _controller.state,
        builder: (context, snapshot) {
          final state = snapshot.data ?? LightConnectionState.disconnected;
          final connected = state == LightConnectionState.connected;

          return SingleChildScrollView(
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
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Effects', style: TextStyle(fontWeight: FontWeight.bold)),
                    OutlinedButton(
                      onPressed: connected ? _syncTime : null,
                      child: const Text('Sync time'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<UniColorEffect>(
                        initialValue: _uniEffect,
                        decoration: const InputDecoration(labelText: 'Single-color effect'),
                        items: [
                          for (final e in UniColorEffect.values)
                            DropdownMenuItem(value: e, child: Text(_formatEnumLabel(e.name))),
                        ],
                        onChanged: (e) => setState(() => _uniEffect = e!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _uniColorIndex,
                        decoration: const InputDecoration(labelText: 'Color'),
                        items: [
                          for (var i = 0; i < uniColorSwatchesRgb.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Container(
                                width: 20,
                                height: 20,
                                color: Color(0xFF000000 | uniColorSwatchesRgb[i]),
                              ),
                            ),
                        ],
                        onChanged: (i) => setState(() => _uniColorIndex = i!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: connected ? _applyUniColor : null,
                  child: const Text('Apply single-color effect'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MultiColorEffect>(
                  initialValue: _multiEffect,
                  decoration: const InputDecoration(labelText: 'Multi-color effect'),
                  items: [
                    for (final e in MultiColorEffect.values)
                      DropdownMenuItem(value: e, child: Text(_formatEnumLabel(e.name))),
                  ],
                  onChanged: (e) => setState(() => _multiEffect = e!),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: connected ? _applyMultiColor : null,
                  child: const Text('Apply multi-color effect'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 48, child: Text('Speed')),
                    Expanded(
                      child: Slider(
                        value: _speed.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: '$_speed',
                        onChanged: connected ? (v) => _applySpeed(v.round()) : null,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                const Text('Timer', style: TextStyle(fontWeight: FontWeight.bold)),
                _timerSlotRow(
                  enabled: _slot1Enabled,
                  onEnabledChanged: (v) => setState(() => _slot1Enabled = v),
                  onTime: _slot1On,
                  offTime: _slot1Off,
                  onPickOn: () => _pickTime(_slot1On, (t) => setState(() => _slot1On = t)),
                  onPickOff: () => _pickTime(_slot1Off, (t) => setState(() => _slot1Off = t)),
                ),
                _timerSlotRow(
                  enabled: _slot2Enabled,
                  onEnabledChanged: (v) => setState(() => _slot2Enabled = v),
                  onTime: _slot2On,
                  offTime: _slot2Off,
                  onPickOn: () => _pickTime(_slot2On, (t) => setState(() => _slot2On = t)),
                  onPickOff: () => _pickTime(_slot2Off, (t) => setState(() => _slot2Off = t)),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: connected ? _applyTimer : null,
                  child: const Text('Save timer'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _timerSlotRow({
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required TimeOfDay onTime,
    required TimeOfDay offTime,
    required VoidCallback onPickOn,
    required VoidCallback onPickOff,
  }) {
    return Row(
      children: [
        Switch(value: enabled, onChanged: onEnabledChanged),
        Expanded(
          child: OutlinedButton(
            onPressed: onPickOn,
            child: Text('On ${onTime.format(context)}'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: onPickOff,
            child: Text('Off ${offTime.format(context)}'),
          ),
        ),
      ],
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
