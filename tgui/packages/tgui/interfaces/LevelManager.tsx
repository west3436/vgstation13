import { useState } from 'react';
import {
  Box,
  Button,
  Collapsible,
  Icon,
  LabeledList,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

// System vLevels (station, centcomm, etc) have IDs 101+
// Must match SYSTEM_VLEVEL_OFFSET in __DEFINES/map.dm
const SYSTEM_VLEVEL_OFFSET = 100;

type Data = {
  zLevels: ZLevelEntryData[];
};

type ZLevelEntryData = {
  index: number;
  name: string;
  ref: string;
  vLevelCount: number;
  hasHolomap: boolean;
  usesHolomap: boolean;
  holomapActive: boolean;
  vLevels: GroupRow[];
};

type FloorRow = {
  floor: number;
  id: number;
  display_id: string;
  ref: string;
  parent_z: number;
  x_min: number;
  x_max: number;
  y_min: number;
  y_max: number;
  sizeX: number;
  sizeY: number;
  mob_count: number;
  player_count: number;
  processingMobs: number;
  pausedMobs: number;
};

type GroupRow = {
  id: number;
  display_id: string;
  name: string;
  ref: string;
  is_multifloor: boolean;
  floor_count: number;
  active: boolean;
  sizeX: number;
  sizeY: number;
  // Aggregate counts (new)
  mob_count: number;
  player_count: number;
  // Legacy aggregate counts (still emitted by backend)
  players: number;
  processingMobs: number;
  pausedMobs: number;
  // Optional links
  planetRef?: string;
  planetName?: string;
  shuttleRef?: string;
  shuttleName?: string;
  // Group-level settings
  movementJammed: boolean;
  gpsAllowed: boolean;
  teleJammed: number;
  transitionLoops: boolean;
  transitionChannel: string;
  // Crosswrap settings
  hasCrosswrap: boolean;
  crosswrapNorth?: number;
  crosswrapSouth?: number;
  crosswrapEast?: number;
  crosswrapWest?: number;
  // Per-floor entries
  floors: FloorRow[];
};

// Teleportation constants (must match DM defines)
const VZ_TELEPORTATION_ALLOWED = 1;
const VZ_TELEPORTATION_EXPENSIVE = 2;
const VZ_TELEPORTATION_FORBIDDEN = 4;

export const LevelManager = () => {
  const { act, data } = useBackend<Data>();
  const { zLevels = [] } = data;

  const totalVLevels = zLevels.reduce((sum, z) => sum + z.vLevelCount, 0);

  return (
    <Window title="Level Manager" width={550} height={500}>
      <Window.Content scrollable>
        <Section
          title={`${zLevels.length} Z-Level${zLevels.length !== 1 ? 's' : ''} | ${totalVLevels} Virtual Z-Level${totalVLevels !== 1 ? 's' : ''}`}
          buttons={
            <>
              <Button
                icon="plus"
                content="New Z-Level"
                onClick={() => act('create_zlevel')}
              />
              <Button
                icon="plus"
                content="New vLevel"
                onClick={() => act('create_vlevel')}
              />
            </>
          }
        >
          <Stack vertical fill>
            {zLevels.map((zLevel) => (
              <Stack.Item key={zLevel.index}>
                <ZLevelEntry zLevel={zLevel} />
              </Stack.Item>
            ))}
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};

const ZLevelEntry = (props: { zLevel: ZLevelEntryData }) => {
  const { act } = useBackend<Data>();
  const { zLevel } = props;
  const [open, setOpen] = useState(false);

  return (
    <Collapsible
      open={open}
      title={
        <Box inline>
          <Box inline bold>
            Z-Level {zLevel.index}: {zLevel.name}
          </Box>
          <Box inline color="label" ml={1}>
            ({zLevel.vLevelCount} vLevel{zLevel.vLevelCount !== 1 ? 's' : ''})
          </Box>
        </Box>
      }
      buttons={
        <>
          <Button
            icon="map"
            selected={zLevel.holomapActive}
            disabled={zLevel.usesHolomap && !zLevel.hasHolomap}
            tooltip={
              zLevel.usesHolomap && !zLevel.hasHolomap
                ? 'No holomap data available'
                : zLevel.usesHolomap
                  ? (zLevel.holomapActive ? 'Hide Holomap' : 'Show Holomap')
                  : (zLevel.holomapActive ? 'Hide Virtual Z-Level Map' : 'Show Virtual Z-Level Map')
            }
            onClick={() => act('show_map', { ref: zLevel.ref })}
          />
          <Button
            icon="search"
            tooltip="View Variables"
            onClick={() => act('vv_zlevel', { ref: zLevel.ref })}
          />
        </>
      }
      onToggle={() => setOpen(!open)}
    >
      {zLevel.vLevels.length === 0 ? (
        <Box color="average" italic p={1}>
          No virtual z-levels on this z-level.
        </Box>
      ) : (
        <Stack vertical>
          {zLevel.vLevels.map((group) => (
            <Stack.Item key={group.id}>
              <VLevelEntry vLevel={group} />
            </Stack.Item>
          ))}
        </Stack>
      )}
    </Collapsible>
  );
};

const getTeleportLabel = (teleJammed: number): string => {
  switch (teleJammed) {
    case VZ_TELEPORTATION_ALLOWED:
      return 'Allowed';
    case VZ_TELEPORTATION_EXPENSIVE:
      return 'Expensive';
    case VZ_TELEPORTATION_FORBIDDEN:
      return 'Forbidden';
    default:
      return 'Unknown';
  }
};

const getTeleportColor = (teleJammed: number): string => {
  switch (teleJammed) {
    case VZ_TELEPORTATION_ALLOWED:
      return 'good';
    case VZ_TELEPORTATION_EXPENSIVE:
      return 'average';
    case VZ_TELEPORTATION_FORBIDDEN:
      return 'bad';
    default:
      return 'label';
  }
};

const VLevelEntry = (props: { vLevel: GroupRow }) => {
  const { act } = useBackend<Data>();
  const { vLevel } = props;
  const [showSettings, setShowSettings] = useState(false);
  const [showFloors, setShowFloors] = useState(false);

  // Base vLevels (IDs 1-6) should never be paused
  const isBaseLevel = vLevel.id >= 1 && vLevel.id <= 6;
  const isMultifloor = !!vLevel.is_multifloor;
  const crosswrapDisabledTooltip =
    'Crosswrap not permitted on multi-floor vlevels.';

  return (
    <Section
      title={
        <Box inline>
          <Icon
            name={vLevel.active ? 'play' : 'pause'}
            color={vLevel.active ? 'good' : 'average'}
            mr={1}
          />
          vZ-{vLevel.display_id}: {vLevel.name}
          {isMultifloor && (
            <Box inline color="label" ml={1}>
              ({vLevel.floor_count} floors)
            </Box>
          )}
        </Box>
      }
      buttons={
        <>
          <Button
            icon={vLevel.active ? 'pause' : 'play'}
            color={vLevel.active ? 'average' : 'good'}
            tooltip={
              isBaseLevel
                ? 'Base levels cannot be paused'
                : vLevel.active
                  ? 'Pause'
                  : 'Activate'
            }
            disabled={isBaseLevel}
            onClick={() => act('toggle_pause', { ref: vLevel.ref })}
          />
          <Button
            icon="arrow-right"
            tooltip="Jump To"
            onClick={() => act('jump', { ref: vLevel.ref })}
          />
          <Button
            icon="plus"
            tooltip="Add a new floor above this vLevel"
            onClick={() => act('add_floor_above', { id: vLevel.id })}
          />
          {isMultifloor && (
            <Button
              icon="minus"
              color="bad"
              tooltip="Remove the topmost floor of this vLevel"
              onClick={() => act('remove_top_floor', { id: vLevel.id })}
            />
          )}
          {vLevel.planetRef && (
            <Button
              icon="globe"
              tooltip={`View Planet: ${vLevel.planetName}`}
              onClick={() => act('vv_planet', { ref: vLevel.ref })}
            />
          )}
          {vLevel.shuttleRef && (
            <Button
              icon="space-shuttle"
              tooltip={`View Shuttle: ${vLevel.shuttleName}`}
              onClick={() => act('vv_shuttle', { ref: vLevel.ref })}
            />
          )}
          <Button
            icon="cog"
            tooltip="Settings"
            selected={showSettings}
            onClick={() => setShowSettings(!showSettings)}
          />
          <Button
            icon="search"
            tooltip="View Variables"
            onClick={() => act('vv_vlevel', { ref: vLevel.ref })}
          />
        </>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Status">
          <Box inline color={vLevel.active ? 'good' : 'average'} bold>
            {vLevel.active ? 'Active' : 'Paused'}
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Dimensions">
          {vLevel.sizeX} x {vLevel.sizeY}
        </LabeledList.Item>
        <LabeledList.Item label="Players">
          <Box inline color={vLevel.player_count > 0 ? 'good' : 'label'}>
            {vLevel.player_count}
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Mobs">
          <Box inline color={vLevel.mob_count > 0 ? 'default' : 'label'}>
            {vLevel.mob_count}
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Processing Mobs">
          <Box inline color={vLevel.processingMobs > 0 ? 'default' : 'label'}>
            {vLevel.processingMobs}
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Paused Mobs">
          <Box inline color={vLevel.pausedMobs > 0 ? 'average' : 'label'}>
            {vLevel.pausedMobs}
          </Box>
        </LabeledList.Item>
      </LabeledList>
      {isMultifloor && (
        <Box mt={1}>
          <Collapsible
            open={showFloors}
            title={
              <Box inline color="label">
                {showFloors ? 'Hide' : 'Show'} {vLevel.floor_count} floor
                {vLevel.floor_count !== 1 ? 's' : ''}
              </Box>
            }
            onToggle={() => setShowFloors(!showFloors)}
          >
            <Stack vertical>
              {vLevel.floors.map((f) => (
                <Stack.Item key={`${f.id}-${f.floor}`}>
                  <Section
                    title={
                      <Box inline>
                        <Box inline bold>
                          Floor {f.floor}
                        </Box>
                        <Box inline color="label" ml={1}>
                          (vZ-{f.display_id})
                        </Box>
                      </Box>
                    }
                    buttons={
                      <>
                        <Button
                          icon="arrow-right"
                          tooltip="Jump to this floor"
                          onClick={() =>
                            act('jump', {
                              id: vLevel.id,
                              floor: f.floor,
                            })
                          }
                        />
                        {f.floor >= 2 && (
                          <Button
                            icon="sync"
                            tooltip="Recompute footprint for this floor"
                            onClick={() =>
                              act('refresh_footprint', {
                                id: vLevel.id,
                                floor: f.floor,
                              })
                            }
                          />
                        )}
                      </>
                    }
                  >
                    <LabeledList>
                      <LabeledList.Item label="Parent Z">
                        {f.parent_z}
                      </LabeledList.Item>
                      <LabeledList.Item label="Footprint">
                        ({f.x_min},{f.y_min}) - ({f.x_max},{f.y_max}) [
                        {f.sizeX} x {f.sizeY}]
                      </LabeledList.Item>
                      <LabeledList.Item label="Players">
                        <Box
                          inline
                          color={f.player_count > 0 ? 'good' : 'label'}
                        >
                          {f.player_count}
                        </Box>
                      </LabeledList.Item>
                      <LabeledList.Item label="Mobs">
                        <Box
                          inline
                          color={f.mob_count > 0 ? 'default' : 'label'}
                        >
                          {f.mob_count}
                        </Box>
                      </LabeledList.Item>
                    </LabeledList>
                  </Section>
                </Stack.Item>
              ))}
            </Stack>
          </Collapsible>
        </Box>
      )}
      {showSettings && (
        <Box mt={2}>
          <Section title="Settings" level={2}>
            <LabeledList>
              <LabeledList.Item label="Inter-vZ Movement">
                <Button
                  icon={vLevel.movementJammed ? 'lock' : 'unlock'}
                  color={vLevel.movementJammed ? 'bad' : 'good'}
                  content={vLevel.movementJammed ? 'Jammed' : 'Allowed'}
                  onClick={() =>
                    act('toggle_movement_jam', { ref: vLevel.ref })
                  }
                />
              </LabeledList.Item>
              <LabeledList.Item label="GPS">
                <Button
                  icon={vLevel.gpsAllowed ? 'satellite' : 'satellite-dish'}
                  color={vLevel.gpsAllowed ? 'good' : 'bad'}
                  content={vLevel.gpsAllowed ? 'Allowed' : 'Jammed'}
                  onClick={() => act('toggle_gps', { ref: vLevel.ref })}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Teleportation">
                <Button
                  icon="bolt"
                  color={getTeleportColor(vLevel.teleJammed)}
                  content={getTeleportLabel(vLevel.teleJammed)}
                  tooltip="Click to cycle: Allowed → Expensive → Forbidden"
                  onClick={() => act('cycle_teleport', { ref: vLevel.ref })}
                />
              </LabeledList.Item>
              {!vLevel.movementJammed && (
                <>
                  <LabeledList.Item label="Transition Loops">
                    <Button
                      icon={vLevel.transitionLoops ? 'sync' : 'random'}
                      color={vLevel.transitionLoops ? 'average' : 'default'}
                      content={vLevel.transitionLoops ? 'Enabled' : 'Disabled'}
                      disabled={isMultifloor}
                      tooltip={
                        isMultifloor ? crosswrapDisabledTooltip : undefined
                      }
                      onClick={() =>
                        act('toggle_transition_loops', { ref: vLevel.ref })
                      }
                    />
                  </LabeledList.Item>
                  <LabeledList.Item label="Transition Channel">
                    <Button
                      icon="layer-group"
                      content={vLevel.transitionChannel}
                      disabled={isMultifloor}
                      tooltip={
                        isMultifloor
                          ? crosswrapDisabledTooltip
                          : 'Change which transition channel this vLevel belongs to for space drift'
                      }
                      onClick={() =>
                        act('change_transition_channel', { ref: vLevel.ref })
                      }
                    />
                  </LabeledList.Item>
                  <LabeledList.Item label="Transition Crosswraps">
                    <Box inline>
                      {vLevel.hasCrosswrap ? (
                        <Box inline color="label" mr={1}>
                          N:{vLevel.crosswrapNorth || '-'} S:
                          {vLevel.crosswrapSouth || '-'} E:
                          {vLevel.crosswrapEast || '-'} W:
                          {vLevel.crosswrapWest || '-'}
                        </Box>
                      ) : (
                        <Box inline color="label" mr={1}>
                          Not configured
                        </Box>
                      )}
                      <Button
                        icon="arrows-alt"
                        content="Configure"
                        disabled={isMultifloor}
                        tooltip={
                          isMultifloor
                            ? crosswrapDisabledTooltip
                            : 'Configure which vLevels to transition to when hitting each edge'
                        }
                        onClick={() =>
                          act('configure_crosswrap', { ref: vLevel.ref })
                        }
                      />
                    </Box>
                  </LabeledList.Item>
                  {isMultifloor && (
                    <LabeledList.Item label="">
                      <Box inline italic color="label">
                        {crosswrapDisabledTooltip}
                      </Box>
                    </LabeledList.Item>
                  )}
                </>
              )}
            </LabeledList>
          </Section>
        </Box>
      )}
    </Section>
  );
};
