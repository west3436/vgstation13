import React from 'react';
import { Box, Button, Icon, LabeledList, NoticeBox, ProgressBar, Section, Table } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type ZoneSample = {
  name: string;
  native_id: number;
  status: string;
  detail: string;
};

type SyncReport = {
  zones_match: boolean | null;
  edges_match: boolean | null;
  active_match: boolean | null;
  dm_zones: number;
  dm_edges: number;
  dm_active: number;
  dll_zones: number;
  dll_edges: number;
  dll_active: number;
  zone_samples: ZoneSample[];
};

// SS state constants from MC.dm
const SS_IDLE = 0;
const SS_RUNNING = 2;
const SS_PAUSED = 3;

type Data = {
  dll_loaded: boolean;
  dll_version: number;

  dm_zones: number;
  dm_edges: number;
  dm_active_edges: number;
  dm_pending_tiles: number;
  dm_pending_zones: number;
  dm_hotspots: number;

  dll_zones: number;
  dll_edges: number;
  dll_active_edges: number;

  cost_tiles: number;
  cost_deferred: number;
  cost_edges: number;
  cost_hotspot: number;
  cost_zones: number;
  cost_total_subsystem: number;
  current_cycle: number;

  air_state: number;
  air_cost: number;
  air_tick_usage: number;
  air_ticks: number;
  air_can_fire: boolean;
  air_times_fired: number;
  air_failed_ticks: number;

  pipenet_state: number;
  pipenet_cost: number;
  pipenet_tick_usage: number;
  pipenet_ticks: number;
  pipenet_can_fire: boolean;
  pipenet_times_fired: number;


  last_dm_tick_ms: number;
  last_dll_tick_ms: number;
  avg_dm_tick_ms: number;
  avg_dll_tick_ms: number;
  benchmark_iterations: number;
  benchmark_running: boolean;
  last_dm_ops: number;
  last_dll_results: number;

  sync_report: SyncReport | null;
  sync_age: number;
};

export const ZasPlusPlus = () => {
  return (
    <Window width={520} height={780}>
      <Window.Content scrollable>
        <ZasPlusPlusContent />
      </Window.Content>
    </Window>
  );
};

const StatusIcon = ({ good }: { good: boolean | null }) => {
  if (good === null) {
    return <Icon name="question-circle" color="gray" />;
  }
  return good ? (
    <Icon name="check-circle" color="good" />
  ) : (
    <Icon name="times-circle" color="bad" />
  );
};

function ssStateName(state: number): string {
  switch (state) {
    case SS_IDLE:
      return 'Idle';
    case SS_RUNNING:
      return 'Running';
    case SS_PAUSED:
      return 'Paused';
    default:
      return 'Sleeping';
  }
}

function ssStateColor(state: number): string {
  switch (state) {
    case SS_RUNNING:
      return 'good';
    case SS_PAUSED:
      return 'average';
    default:
      return 'label';
  }
}

const ZasPlusPlusContent = () => {
  const { data, act } = useBackend<Data>();

  return (
    <>
      <SubsystemHealthSection data={data} />
      <StateSection data={data} />
      <TickCostSection data={data} />
      <BenchmarkSection data={data} act={act} />
      <SyncSection data={data} act={act} />
    </>
  );
};

const SubsystemHealthSection = ({ data }: { data: Data }) => {
  const airOverloaded = data.air_cost > 30 || data.air_ticks > 3;
  const pipenetOverloaded =
    data.pipenet_cost > 30 || data.pipenet_ticks > 3;

  return (
    <Section title="Subsystem Health">
      {(airOverloaded || pipenetOverloaded) && (
        <NoticeBox danger>
          {airOverloaded && 'SSair is overloaded! '}
          {pipenetOverloaded && 'SSpipenet is overloaded!'}
        </NoticeBox>
      )}
      <Table>
        <Table.Row header>
          <Table.Cell>Subsystem</Table.Cell>
          <Table.Cell>State</Table.Cell>
          <Table.Cell>Cost</Table.Cell>
          <Table.Cell>Tick %</Table.Cell>
          <Table.Cell>Ticks</Table.Cell>
          <Table.Cell>Fired</Table.Cell>
        </Table.Row>
        <Table.Row>
          <Table.Cell bold>
            SSair
            {!data.air_can_fire && (
              <Box as="span" color="bad" ml={1}>
                [STOPPED]
              </Box>
            )}
          </Table.Cell>
          <Table.Cell color={ssStateColor(data.air_state)}>
            {ssStateName(data.air_state)}
          </Table.Cell>
          <Table.Cell color={data.air_cost > 30 ? 'bad' : data.air_cost > 15 ? 'average' : 'good'}>
            {data.air_cost}ms
          </Table.Cell>
          <Table.Cell color={data.air_tick_usage > 80 ? 'bad' : data.air_tick_usage > 50 ? 'average' : 'good'}>
            {data.air_tick_usage}%
          </Table.Cell>
          <Table.Cell color={data.air_ticks > 3 ? 'bad' : data.air_ticks > 1.5 ? 'average' : 'good'}>
            {data.air_ticks}
          </Table.Cell>
          <Table.Cell>{data.air_times_fired}</Table.Cell>
        </Table.Row>
        <Table.Row>
          <Table.Cell bold>
            SSpipenet
            {!data.pipenet_can_fire && (
              <Box as="span" color="bad" ml={1}>
                [STOPPED]
              </Box>
            )}
          </Table.Cell>
          <Table.Cell color={ssStateColor(data.pipenet_state)}>
            {ssStateName(data.pipenet_state)}
          </Table.Cell>
          <Table.Cell color={data.pipenet_cost > 30 ? 'bad' : data.pipenet_cost > 15 ? 'average' : 'good'}>
            {data.pipenet_cost}ms
          </Table.Cell>
          <Table.Cell color={data.pipenet_tick_usage > 80 ? 'bad' : data.pipenet_tick_usage > 50 ? 'average' : 'good'}>
            {data.pipenet_tick_usage}%
          </Table.Cell>
          <Table.Cell color={data.pipenet_ticks > 3 ? 'bad' : data.pipenet_ticks > 1.5 ? 'average' : 'good'}>
            {data.pipenet_ticks}
          </Table.Cell>
          <Table.Cell>{data.pipenet_times_fired}</Table.Cell>
        </Table.Row>
      </Table>
      <Box mt={1}>
        <LabeledList>
          <LabeledList.Item label="DLL">
            <StatusIcon good={data.dll_loaded} />
            {' '}v{data.dll_version}
          </LabeledList.Item>
          <LabeledList.Item label="Air Cycle">
            {data.current_cycle}
          </LabeledList.Item>
          {data.air_failed_ticks > 0 && (
            <LabeledList.Item label="Failed Ticks">
              <Box color="bad" bold>
                {data.air_failed_ticks}
              </Box>
            </LabeledList.Item>
          )}
        </LabeledList>
      </Box>
    </Section>
  );
};

const StateSection = ({ data }: { data: Data }) => {
  const hasDll = data.dll_zones >= 0;
  return (
    <Section title="State Overview">
      <Table>
        <Table.Row header>
          <Table.Cell>Metric</Table.Cell>
          <Table.Cell>DM</Table.Cell>
          {hasDll && <Table.Cell>DLL</Table.Cell>}
          {hasDll && <Table.Cell>Match</Table.Cell>}
        </Table.Row>
        <Table.Row>
          <Table.Cell>Zones</Table.Cell>
          <Table.Cell>{data.dm_zones}</Table.Cell>
          {hasDll && <Table.Cell>{data.dll_zones}</Table.Cell>}
          {hasDll && (
            <Table.Cell>
              <StatusIcon good={data.dm_zones === data.dll_zones} />
            </Table.Cell>
          )}
        </Table.Row>
        <Table.Row>
          <Table.Cell>Edges</Table.Cell>
          <Table.Cell>{data.dm_edges}</Table.Cell>
          {hasDll && <Table.Cell>{data.dll_edges}</Table.Cell>}
          {hasDll && (
            <Table.Cell>
              <StatusIcon good={data.dm_edges === data.dll_edges} />
            </Table.Cell>
          )}
        </Table.Row>
        <Table.Row>
          <Table.Cell>Active Edges</Table.Cell>
          <Table.Cell>{data.dm_active_edges}</Table.Cell>
          {hasDll && <Table.Cell>{data.dll_active_edges}</Table.Cell>}
          {hasDll && (
            <Table.Cell>
              <StatusIcon
                good={data.dm_active_edges === data.dll_active_edges}
              />
            </Table.Cell>
          )}
        </Table.Row>
        <Table.Row>
          <Table.Cell>Pending Tiles</Table.Cell>
          <Table.Cell>{data.dm_pending_tiles}</Table.Cell>
          {hasDll && <Table.Cell>-</Table.Cell>}
          {hasDll && <Table.Cell>-</Table.Cell>}
        </Table.Row>
        <Table.Row>
          <Table.Cell>Pending Zones</Table.Cell>
          <Table.Cell>{data.dm_pending_zones}</Table.Cell>
          {hasDll && <Table.Cell>-</Table.Cell>}
          {hasDll && <Table.Cell>-</Table.Cell>}
        </Table.Row>
        <Table.Row>
          <Table.Cell color={data.dm_hotspots > 1000 ? 'bad' : data.dm_hotspots > 100 ? 'average' : undefined}>
            Hotspots
          </Table.Cell>
          <Table.Cell color={data.dm_hotspots > 1000 ? 'bad' : data.dm_hotspots > 100 ? 'average' : undefined} bold={data.dm_hotspots > 1000}>
            {data.dm_hotspots}
          </Table.Cell>
          {hasDll && <Table.Cell>-</Table.Cell>}
          {hasDll && <Table.Cell>-</Table.Cell>}
        </Table.Row>
      </Table>
    </Section>
  );
};

const TickCostSection = ({ data }: { data: Data }) => {
  const partsTotal =
    data.cost_tiles +
    data.cost_deferred +
    data.cost_edges +
    data.cost_hotspot +
    data.cost_zones;
  const subsystemTotal = data.cost_total_subsystem;
  const overhead = Math.max(0, Math.round((subsystemTotal - partsTotal) * 100) / 100);
  const maxBar = Math.max(subsystemTotal, partsTotal, 1);

  return (
    <Section title="SSair Tick Costs (ms)">
      <LabeledList>
        <LabeledList.Item label="Tiles">
          <ProgressBar
            value={data.cost_tiles}
            maxValue={maxBar}
            color="blue"
          >
            {data.cost_tiles} ms
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Deferred">
          <ProgressBar
            value={data.cost_deferred}
            maxValue={maxBar}
            color="blue"
          >
            {data.cost_deferred} ms
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Edges">
          <ProgressBar
            value={data.cost_edges}
            maxValue={maxBar}
            color="green"
          >
            {data.cost_edges} ms (DLL)
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Hotspots">
          <ProgressBar
            value={data.cost_hotspot}
            maxValue={maxBar}
            color={data.cost_hotspot > 15 ? 'bad' : data.cost_hotspot > 5 ? 'orange' : 'blue'}
          >
            {data.cost_hotspot} ms
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Zones">
          <ProgressBar
            value={data.cost_zones}
            maxValue={maxBar}
            color="green"
          >
            {data.cost_zones} ms (DLL)
          </ProgressBar>
        </LabeledList.Item>
        {overhead > 0.1 && (
          <LabeledList.Item label="Overhead">
            <ProgressBar
              value={overhead}
              maxValue={maxBar}
              color="average"
            >
              {overhead} ms (MC scheduling, pause/resume)
            </ProgressBar>
          </LabeledList.Item>
        )}
        <LabeledList.Item label="Parts Total">
          <Box bold color={partsTotal > 30 ? 'bad' : partsTotal > 15 ? 'average' : 'good'}>
            {Math.round(partsTotal * 100) / 100} ms
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="SS Total">
          <Box bold color={subsystemTotal > 30 ? 'bad' : subsystemTotal > 15 ? 'average' : 'good'}>
            {subsystemTotal} ms
            {subsystemTotal > partsTotal * 2 && (
              <Box as="span" color="bad" ml={1}>
                (multi-tick)
              </Box>
            )}
          </Box>
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const BenchmarkSection = ({
  data,
  act,
}: {
  data: Data;
  act: (action: string) => void;
}) => {
  const speedup =
    data.avg_dm_tick_ms > 0 && data.avg_dll_tick_ms > 0
      ? data.avg_dm_tick_ms / data.avg_dll_tick_ms
      : 0;
  const maxBar = Math.max(data.avg_dm_tick_ms, data.avg_dll_tick_ms, 0.01);

  return (
    <Section
      title="Benchmark"
      buttons={
        <>
          <Button
            icon={data.benchmark_running ? 'spinner' : 'play'}
            disabled={data.benchmark_running}
            onClick={() => act('benchmark')}
          >
            {data.benchmark_running ? 'Running...' : 'Run'}
          </Button>
          <Button
            icon="redo"
            disabled={data.benchmark_running}
            onClick={() => act('reset_benchmark')}
          >
            Reset
          </Button>
          <Button
            icon="fire"
            color="bad"
            onClick={() => act('stress_test')}
          >
            Stress Test
          </Button>
        </>
      }
    >
      {data.benchmark_iterations === 0 ? (
        <NoticeBox info>
          Compares DM compare() vs DLL tick_edges() across all edges.
        </NoticeBox>
      ) : (
        <LabeledList>
          <LabeledList.Item label="DM (compare)">
            <ProgressBar value={data.avg_dm_tick_ms} maxValue={maxBar} color="orange">
              {data.avg_dm_tick_ms} ms ({data.last_dm_ops} edges)
            </ProgressBar>
          </LabeledList.Item>
          <LabeledList.Item label="DLL (tick_edges)">
            <ProgressBar
              value={data.avg_dll_tick_ms}
              maxValue={maxBar}
              color="green"
            >
              {data.avg_dll_tick_ms} ms ({data.last_dll_results} results)
            </ProgressBar>
          </LabeledList.Item>
          {speedup > 0 && (
            <LabeledList.Item label="Speedup">
              <Box
                color={speedup >= 1 ? 'good' : 'bad'}
                bold
              >
                {Math.round(speedup * 100) / 100}x
                {speedup >= 1 ? ' faster' : ' slower'}
              </Box>
            </LabeledList.Item>
          )}
          <LabeledList.Item label="Iterations">
            {data.benchmark_iterations}
          </LabeledList.Item>
        </LabeledList>
      )}
    </Section>
  );
};

const SyncSection = ({
  data,
  act,
}: {
  data: Data;
  act: (action: string) => void;
}) => {
  const report = data.sync_report;

  return (
    <Section
      title="State Sync"
      buttons={
        <>
          <Button icon="sync" onClick={() => act('sync_check')}>
            Check
          </Button>
          <Button icon="upload" onClick={() => act('resync')}>
            Resync Zones
          </Button>
        </>
      }
    >
      {!report ? (
        <NoticeBox info>
          Click Check to compare DM and DLL state.
        </NoticeBox>
      ) : (
        <>
          {data.sync_age >= 0 && (
            <Box mb={1} color="label" italic>
              Last checked {data.sync_age}s ago
            </Box>
          )}
          <LabeledList>
            <LabeledList.Item label="Zones">
              <StatusIcon good={report.zones_match} />
              {' '}DM: {report.dm_zones} / DLL: {report.dll_zones}
            </LabeledList.Item>
            <LabeledList.Item label="Edges">
              <StatusIcon good={report.edges_match} />
              {' '}DM: {report.dm_edges} / DLL: {report.dll_edges}
            </LabeledList.Item>
            <LabeledList.Item label="Active">
              <StatusIcon good={report.active_match} />
              {' '}DM: {report.dm_active} / DLL: {report.dll_active}
            </LabeledList.Item>
          </LabeledList>

          {report.zone_samples && report.zone_samples.length > 0 && (
            <Box mt={1}>
              <Table>
                <Table.Row header>
                  <Table.Cell>Zone</Table.Cell>
                  <Table.Cell>Status</Table.Cell>
                  <Table.Cell>Detail</Table.Cell>
                </Table.Row>
                {report.zone_samples.map((sample, i) => (
                  <Table.Row key={i}>
                    <Table.Cell>{sample.name}</Table.Cell>
                    <Table.Cell>
                      <Box
                        color={
                          sample.status === 'synced'
                            ? 'good'
                            : sample.status === 'diverged'
                              ? 'bad'
                              : 'average'
                        }
                      >
                        {sample.status}
                      </Box>
                    </Table.Cell>
                    <Table.Cell>{sample.detail}</Table.Cell>
                  </Table.Row>
                ))}
              </Table>
            </Box>
          )}
        </>
      )}
    </Section>
  );
};
