import { useState } from 'react';
import { Box, Button, Collapsible, NumberInput, ProgressBar, Section, Stack } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type BeaconData = {
  tag: string;
  active: boolean;
  location: string;
};

type PlanetData = {
  name: string;
  desc: string;
  type: string;
  procedural_name: string;
  icon_data: string;
  beacons: BeaconData[];
  has_active_beacon: boolean;
  // Planet parameters
  altitude: number;
  gravity: number;
  temperature: number;
  humidity: number;
  atmosphere: number;
};

type FilterData = {
  enabled: boolean;
  min: number;
  max: number;
  range_min: number;
  range_max: number;
};

type FiltersData = {
  altitude: FilterData;
  gravity: FilterData;
  temperature: FilterData;
  humidity: FilterData;
  atmosphere: FilterData;
};

type Data = {
  anchored: boolean;
  powered: boolean;
  scanning: boolean;
  scans_completed: number;
  max_scans: number;
  progress: number;
  required_energy: number;
  min_power_rate: number;
  available_power: number;
  current_energy: number | null;
  can_scan: boolean;
  at_scan_limit: boolean;
  discovered_planets: PlanetData[] | null;
  has_discoveries: boolean;
  waiting_for_generation: boolean;
  generation_stage: number | null;
  generation_progress: number | null;
  other_scan_in_progress: boolean;
  scanning_disabled: boolean;
  // Filter data
  filters: FiltersData;
  active_filter_count: number;
  filter_multiplier: number;
};

const STAGE_TERRAIN = 1;
const STAGE_RUIN = 2;
const STAGE_POPULATION = 3;
const STAGE_WEATHER = 4;
const STAGE_FINALIZE = 5;

// Helper to format parameter values for display
const formatParam = (value: number, decimals: number = 2): string => {
  return value?.toFixed(decimals) ?? 'N/A';
};

// Helper to get color based on value in a range
const getParamColor = (value: number, low: number = 0.33, high: number = 0.66): string => {
  if (value <= low) return 'blue';
  if (value >= high) return 'red';
  return 'average';
};

// Filter row component
const FilterRow = ({ name, label, filter, act, disabled }: {
  name: string;
  label: string;
  filter: FilterData;
  act: Function;
  disabled: boolean;
}) => (
  <Stack mb={0.5} align="center">
    <Stack.Item basis="25%">
      <Button
        icon={filter.enabled ? 'check-square-o' : 'square-o'}
        content={label}
        selected={filter.enabled}
        disabled={disabled}
        onClick={() => act('toggle_filter', { filter: name })}
      />
    </Stack.Item>
    {filter.enabled && (
      <>
        <Stack.Item basis="35%">
          <Stack align="center">
            <Stack.Item>Min:</Stack.Item>
            <Stack.Item grow>
              <NumberInput
                value={filter.min}
                minValue={filter.range_min}
                maxValue={filter.max}
                step={0.1}
                format={(v) => v.toFixed(2)}
                onChange={(value) => act('set_filter_min', { filter: name, value })}
              />
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item basis="35%">
          <Stack align="center">
            <Stack.Item>Max:</Stack.Item>
            <Stack.Item grow>
              <NumberInput
                value={filter.max}
                minValue={filter.min}
                maxValue={filter.range_max}
                step={0.1}
                format={(v) => v.toFixed(2)}
                onChange={(value) => act('set_filter_max', { filter: name, value })}
              />
            </Stack.Item>
          </Stack>
        </Stack.Item>
      </>
    )}
  </Stack>
);

// Planet parameters display component
const PlanetParameters = ({ planet }: { planet: PlanetData }) => (
  <Box fontSize="11px" mb={1}>
    <Stack wrap>
      <Stack.Item basis="50%">
        <Box color="label" inline>Altitude: </Box>
        <Box color={getParamColor(planet.altitude)} inline bold>
          {formatParam(planet.altitude)}
        </Box>
      </Stack.Item>
      <Stack.Item basis="50%">
        <Box color="label" inline>Gravity: </Box>
        <Box color={planet.gravity > 1.2 ? 'red' : planet.gravity < 0.8 ? 'blue' : 'average'} inline bold>
          {formatParam(planet.gravity)}g
        </Box>
      </Stack.Item>
      <Stack.Item basis="50%">
        <Box color="label" inline>Temp: </Box>
        <Box color={getParamColor(planet.temperature)} inline bold>
          {formatParam(planet.temperature)}
        </Box>
      </Stack.Item>
      <Stack.Item basis="50%">
        <Box color="label" inline>Humidity: </Box>
        <Box color={getParamColor(planet.humidity)} inline bold>
          {formatParam(planet.humidity)}
        </Box>
      </Stack.Item>
      <Stack.Item basis="50%">
        <Box color="label" inline>Atmo: </Box>
        <Box color={planet.atmosphere < 0.7 ? 'red' : planet.atmosphere > 1.3 ? 'average' : 'good'} inline bold>
          {formatParam(planet.atmosphere)}
        </Box>
      </Stack.Item>
    </Stack>
  </Box>
);

export const PlanetScanner = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    anchored,
    powered,
    scanning,
    scans_completed,
    max_scans,
    progress,
    required_energy,
    min_power_rate,
    available_power,
    current_energy,
    can_scan,
    at_scan_limit,
    discovered_planets,
    has_discoveries,
    waiting_for_generation,
    generation_stage,
    generation_progress,
    other_scan_in_progress,
    scanning_disabled,
    filters,
    active_filter_count,
    filter_multiplier,
  } = data;

  // State for cycling through planets
  const [currentPlanetIndex, setCurrentPlanetIndex] = useState(0);

  // Only compute planet-related data when powered and anchored
  const currentPlanet = (powered && anchored && discovered_planets && discovered_planets.length > 0)
    ? discovered_planets[currentPlanetIndex]
    : null;

  const totalPlanets = (powered && anchored && discovered_planets) ? discovered_planets.length : 0;

  // Reset planet index if it's out of bounds
  if (currentPlanetIndex >= totalPlanets && totalPlanets > 0) {
    setCurrentPlanetIndex(0);
  }

  // Navigation functions
  const goToPreviousPlanet = () => {
    if (totalPlanets > 0) {
      setCurrentPlanetIndex((prev) =>
        prev > 0 ? prev - 1 : totalPlanets - 1
      );
    }
  };

  const goToNextPlanet = () => {
    if (totalPlanets > 0) {
      setCurrentPlanetIndex((prev) =>
        prev < totalPlanets - 1 ? prev + 1 : 0
      );
    }
  };

  const filtersDisabled = scanning || waiting_for_generation;

  return (
    <Window width={620} height={560}>
      <Window.Content>
        <Stack fill vertical>
          {!anchored && (
            <Stack.Item>
              <Section>
                <Box color="bad">Scanner must be anchored before operation</Box>
              </Section>
            </Stack.Item>
          )}

          {!powered && !!anchored && (
            <Stack.Item>
              <Section>
                <Box color="bad">No power</Box>
              </Section>
            </Stack.Item>
          )}

          {!!scanning_disabled && !!powered && !!anchored && (
            <Stack.Item grow>
              <Section fill>
                <Stack fill vertical justify="center" align="center">
                  <Stack.Item>
                    <Box
                      fontSize="48px"
                      color="bad"
                      bold
                      textAlign="center"
                      mb={2}
                    >
                      ACCESS DENIED
                    </Box>
                  </Stack.Item>
                  <Stack.Item>
                    <Box
                      fontSize="20px"
                      color="bad"
                      textAlign="center"
                      mb={1}
                    >
                      DEEP SPACE SCANNING DISABLED
                    </Box>
                  </Stack.Item>
                  <Stack.Item>
                    <Box
                      fontSize="14px"
                      color="label"
                      textAlign="center"
                      style={{ maxWidth: '400px' }}
                    >
                      The exploration program has been suspended pending administrative review.
                    </Box>
                  </Stack.Item>
                  <Stack.Item mt={2}>
                    <Box
                      fontSize="12px"
                      color="average"
                      textAlign="center"
                      style={{
                        fontFamily: 'monospace',
                        border: '2px solid #aa5500',
                        padding: '8px 16px',
                        backgroundColor: '#331100',
                        borderRadius: '4px'
                      }}
                    >
                      AUTHORIZATION REQUIRED
                    </Box>
                  </Stack.Item>
                </Stack>
              </Section>
            </Stack.Item>
          )}

          {!!powered && !!anchored && !scanning_disabled && (
            <>
              <Stack.Item>
                <Section title="Scanner Status">
                  <Stack vertical>
                    <Stack.Item>
                      <Stack>
                        <Stack.Item basis="40%">
                          Available Power:
                        </Stack.Item>
                        <Stack.Item grow>
                          <ProgressBar
                            value={available_power || 0}
                            maxValue={Math.max(available_power || 0, min_power_rate || 1)}
                            color="good"
                          >
                            {available_power?.toLocaleString() || 0} W / {min_power_rate?.toLocaleString() || 0} W
                          </ProgressBar>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>
                    {!!at_scan_limit && (
                      <Stack.Item>
                        Scans Completed: {scans_completed} / {max_scans}
                      </Stack.Item>
                    )}
                  </Stack>
                </Section>
              </Stack.Item>

              <Stack.Item>
                <Collapsible title={`Scan Filters${active_filter_count > 0 ? ` (${active_filter_count} active - ${filter_multiplier.toFixed(2)}x power)` : ''}`}>
                  <Box fontSize="12px" color="label" mb={1}>
                    Each filter increases scan power cost by 50%. Filters narrow which planet types can be discovered.
                  </Box>
                  {filters && (
                    <>
                      <FilterRow name="altitude" label="Altitude" filter={filters.altitude} act={act} disabled={filtersDisabled} />
                      <FilterRow name="gravity" label="Gravity" filter={filters.gravity} act={act} disabled={filtersDisabled} />
                      <FilterRow name="temperature" label="Temperature" filter={filters.temperature} act={act} disabled={filtersDisabled} />
                      <FilterRow name="humidity" label="Humidity" filter={filters.humidity} act={act} disabled={filtersDisabled} />
                      <FilterRow name="atmosphere" label="Atmosphere" filter={filters.atmosphere} act={act} disabled={filtersDisabled} />
                    </>
                  )}
                </Collapsible>
              </Stack.Item>

              {!!scanning && !waiting_for_generation && (
                <Stack.Item>
                  <Section title="Scanning Progress">
                    <ProgressBar value={progress} maxValue={100} />
                  </Section>
                </Stack.Item>
              )}

              {!!waiting_for_generation && (
                <Stack.Item>
                  <Section title="Generating Planet...">
                    <Stack vertical>
                      <Stack.Item>
                        <Box mb={0.5}>Analyzing Altimetry</Box>
                        <ProgressBar
                          value={generation_stage >= STAGE_TERRAIN ? (generation_stage > STAGE_TERRAIN ? 100 : generation_progress) : 0}
                          maxValue={100}
                          color={generation_stage > STAGE_TERRAIN ? "good" : generation_stage === STAGE_TERRAIN ? "average" : "default"}
                        />
                      </Stack.Item>
                      <Stack.Item>
                        <Box mb={0.5}>Classifying Flora & Fauna</Box>
                        <ProgressBar
                          value={generation_stage >= STAGE_POPULATION ? (generation_stage > STAGE_POPULATION ? 100 : generation_progress) : 0}
                          maxValue={100}
                          color={generation_stage > STAGE_POPULATION ? "good" : generation_stage === STAGE_POPULATION ? "average" : "default"}
                        />
                      </Stack.Item>
                      <Stack.Item>
                        <Box mb={0.5}>Writing data to memory</Box>
                        <ProgressBar
                          value={generation_stage >= STAGE_WEATHER ? 100 : 0}
                          maxValue={100}
                          color={generation_stage >= STAGE_FINALIZE ? "good" : generation_stage >= STAGE_WEATHER ? "average" : "default"}
                        />
                      </Stack.Item>
                    </Stack>
                  </Section>
                </Stack.Item>
              )}

              {!!has_discoveries && !scanning && !waiting_for_generation && (
                <Stack.Item grow>
                  <Section title="Discovered Planets">
                    <Stack>
                      <Stack.Item width="200px">
                        <Box textAlign="center">
                          <Box
                            as="img"
                            src={currentPlanet ? `data:image/png;base64,${currentPlanet.icon_data}` : undefined}
                            height="180px"
                            width="180px"
                            style={{
                              border: '2px solid #888',
                              backgroundColor: '#333',
                              borderRadius: '8px',
                              imageRendering: 'pixelated',
                            }}
                          />
                          <Box mt={1} fontSize="12px" color="label">
                            {currentPlanet ? currentPlanet.name : 'No Planet Type'}
                          </Box>
                        </Box>
                      </Stack.Item>
                      <Stack.Item grow>
                        <Stack vertical fill>
                          <Stack.Item>
                            <Stack>
                              <Stack.Item grow>
                                <Box fontSize="18px" bold color="good">
                                  {currentPlanet ? currentPlanet.procedural_name : 'No Planet Selected'}
                                </Box>
                              </Stack.Item>
                              <Stack.Item>
                                <Box fontSize="12px" color="label">
                                  {totalPlanets > 0 ? `${currentPlanetIndex + 1} / ${totalPlanets}` : '0 / 0'}
                                </Box>
                              </Stack.Item>
                            </Stack>
                          </Stack.Item>
                          <Stack.Item>
                            <Box mb={1} fontSize="13px">
                              {currentPlanet ? currentPlanet.desc : 'No planet data available.'}
                            </Box>
                          </Stack.Item>
                          {currentPlanet && (
                            <Stack.Item>
                              <PlanetParameters planet={currentPlanet} />
                            </Stack.Item>
                          )}
                          {currentPlanet && currentPlanet.beacons && currentPlanet.beacons.length > 0 && (
                            <Stack.Item>
                              <Box mb={0.5} fontSize="12px" bold>
                                Active Trackers:
                              </Box>
                              {currentPlanet.beacons.map((beacon, index) => (
                                <Box
                                  key={index}
                                  fontSize="11px"
                                  color={beacon.active ? "bad" : "label"}
                                  bold={beacon.active}
                                  mb={0.25}
                                >
                                  {beacon.active ? "! " : ""}{beacon.tag}
                                </Box>
                              ))}
                            </Stack.Item>
                          )}
                          <Stack.Item>
                            <Stack>
                              <Stack.Item>
                                <Button
                                  icon="chevron-left"
                                  content="Previous"
                                  disabled={totalPlanets <= 1}
                                  onClick={goToPreviousPlanet}
                                />
                              </Stack.Item>
                              <Stack.Item>
                                <Button
                                  icon="chevron-right"
                                  content="Next"
                                  disabled={totalPlanets <= 1}
                                  onClick={goToNextPlanet}
                                />
                              </Stack.Item>
                              <Stack.Item grow />
                              <Stack.Item>
                                <Button
                                  icon="save"
                                  content="Print Disk"
                                  disabled={!currentPlanet}
                                  onClick={() => act('print_disk', { planet_index: currentPlanetIndex })}
                                  tooltip="Create a destination disk for this planet"
                                />
                              </Stack.Item>
                            </Stack>
                          </Stack.Item>
                        </Stack>
                      </Stack.Item>
                    </Stack>
                  </Section>
                </Stack.Item>
              )}

              {!has_discoveries && !scanning && !waiting_for_generation && !at_scan_limit && (
                <Stack.Item grow>
                  <Section title="Deep Space Scanner">
                    <Box textAlign="center" color="label" fontSize="14px">
                      No planets discovered yet. Start a scan to explore the cosmos.
                    </Box>
                  </Section>
                </Stack.Item>
              )}

              <Stack.Item>
                <Section>
                  <Button
                    fluid
                    icon="satellite-dish"
                    content={
                      scanning
                        ? "Scanning..."
                        : at_scan_limit
                        ? "Maximum scans reached"
                        : `Start Planet Scan${active_filter_count > 0 ? ` (${filter_multiplier.toFixed(2)}x cost)` : ''}`
                    }
                    disabled={!can_scan}
                    onClick={() => act('start_scan')}
                    tooltip={
                      other_scan_in_progress
                        ? "A planet scan is already in progress on this station - multiple scans are disabled due to electrical infetterence."
                        : at_scan_limit
                        ? "Maximum scans reached"
                        : `Requires ${required_energy?.toLocaleString() || 0} J of energy`
                    }
                  />
                </Section>
              </Stack.Item>
            </>
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};
