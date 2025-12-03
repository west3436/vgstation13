import { useState } from 'react';
import { Box, Button, Dropdown, ProgressBar, Section, Stack } from 'tgui-core/components';

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
  actual_heat: number | null;
  actual_humidity: number | null;
  actual_terrain: number | null;
  actual_atmosphere: number | null;
};

type Data = {
  anchored: boolean;
  powered: boolean;
  scanning: boolean;
  scans_completed: number;
  max_scans: number;
  progress: number;
  required_energy: number;
  base_energy: number;
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
  filtered_heat: number | null;
  filtered_humidity: number | null;
  filtered_terrain: number | null;
  filtered_atmosphere: number | null;
  filter_cost_multiplier: number;
  possible_planets: string[];
  estimated_scan_time: number;
  has_filters: boolean;
};

const STAGE_TERRAIN = 1;
const STAGE_RUIN = 2;
const STAGE_POPULATION = 3;
const STAGE_WEATHER = 4;
const STAGE_FINALIZE = 5;

// Filter option mappings (value matches DM defines)
const HEAT_OPTIONS = [
  { value: 0, label: 'Any' },
  { value: 1, label: 'Very Cold' },
  { value: 2, label: 'Cold' },
  { value: 3, label: 'Temperate' },
  { value: 4, label: 'Hot' },
  { value: 5, label: 'Very Hot' },
];

const HUMIDITY_OPTIONS = [
  { value: 0, label: 'Any' },
  { value: 1, label: 'Very Dry' },
  { value: 2, label: 'Dry' },
  { value: 3, label: 'Moderate' },
  { value: 4, label: 'Humid' },
  { value: 5, label: 'Very Humid' },
];

const TERRAIN_OPTIONS = [
  { value: 0, label: 'Any' },
  { value: 1, label: 'Flat' },
  { value: 2, label: 'Hilly' },
  { value: 3, label: 'Mountainous' },
];

const ATMOSPHERE_OPTIONS = [
  { value: 0, label: 'Any' },
  { value: 1, label: 'None' },
  { value: 2, label: 'Thin' },
  { value: 4, label: 'Breathable' },
  { value: 8, label: 'Toxic' },
  { value: 16, label: 'Radioactive' },
];

// Helper to format time
const formatTime = (seconds: number): string => {
  if (seconds < 0) return 'N/A';
  if (seconds < 60) return `${Math.round(seconds)}s`;
  if (seconds < 3600) return `${Math.round(seconds / 60)}m`;
  return `${(seconds / 3600).toFixed(1)}h`;
};

// Helper to get label from value
const getLabel = (options: { value: number; label: string }[], value: number | null): string => {
  const option = options.find(o => o.value === (value || 0));
  return option?.label || 'Any';
};

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
    base_energy,
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
    filtered_heat,
    filtered_humidity,
    filtered_terrain,
    filtered_atmosphere,
    filter_cost_multiplier,
    possible_planets,
    estimated_scan_time,
    has_filters,
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

  return (
    <Window width={600} height={620}>
      <Window.Content>
        <Stack fill vertical>
          {!anchored && (
            <Stack.Item>
              <Section>
                <Box color="bad">Scanner must be anchored before operation</Box>
              </Section>
            </Stack.Item>
          )}

          {!powered && anchored && (
            <Stack.Item>
              <Section>
                <Box color="bad">No power</Box>
              </Section>
            </Stack.Item>
          )}

          {!!powered && anchored && (
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

              {!scanning && !waiting_for_generation && (
                <Stack.Item>
                  <Section
                    title="Scan Filters"
                    buttons={
                      <Button
                        icon="times"
                        content="Clear Filters"
                        disabled={!has_filters}
                        onClick={() => act('clear_filters')}
                      />
                    }
                  >
                    <Stack vertical>
                      <Stack.Item>
                        <Stack>
                          <Stack.Item basis="25%">
                            <Box mb={0.5} fontSize="12px" color="label">Temperature</Box>
                            <Dropdown
                              width="100%"
                              selected={getLabel(HEAT_OPTIONS, filtered_heat)}
                              options={HEAT_OPTIONS.map(o => o.label)}
                              onSelected={(val) => {
                                const option = HEAT_OPTIONS.find(o => o.label === val);
                                act('set_filter_heat', { value: option?.value || 0 });
                              }}
                            />
                          </Stack.Item>
                          <Stack.Item basis="25%">
                            <Box mb={0.5} fontSize="12px" color="label">Humidity</Box>
                            <Dropdown
                              width="100%"
                              selected={getLabel(HUMIDITY_OPTIONS, filtered_humidity)}
                              options={HUMIDITY_OPTIONS.map(o => o.label)}
                              onSelected={(val) => {
                                const option = HUMIDITY_OPTIONS.find(o => o.label === val);
                                act('set_filter_humidity', { value: option?.value || 0 });
                              }}
                            />
                          </Stack.Item>
                          <Stack.Item basis="25%">
                            <Box mb={0.5} fontSize="12px" color="label">Terrain</Box>
                            <Dropdown
                              width="100%"
                              selected={getLabel(TERRAIN_OPTIONS, filtered_terrain)}
                              options={TERRAIN_OPTIONS.map(o => o.label)}
                              onSelected={(val) => {
                                const option = TERRAIN_OPTIONS.find(o => o.label === val);
                                act('set_filter_terrain', { value: option?.value || 0 });
                              }}
                            />
                          </Stack.Item>
                          <Stack.Item basis="25%">
                            <Box mb={0.5} fontSize="12px" color="label">Atmosphere</Box>
                            <Dropdown
                              width="100%"
                              selected={getLabel(ATMOSPHERE_OPTIONS, filtered_atmosphere)}
                              options={ATMOSPHERE_OPTIONS.map(o => o.label)}
                              onSelected={(val) => {
                                const option = ATMOSPHERE_OPTIONS.find(o => o.label === val);
                                act('set_filter_atmosphere', { value: option?.value || 0 });
                              }}
                            />
                          </Stack.Item>
                        </Stack>
                      </Stack.Item>
                      <Stack.Item>
                        <Stack mt={1}>
                          <Stack.Item grow>
                            <Box fontSize="12px">
                              <Box as="span" color="label">Cost Multiplier: </Box>
                              <Box as="span" color={filter_cost_multiplier > 1 ? "average" : "good"} bold>
                                {filter_cost_multiplier.toFixed(2)}x
                              </Box>
                              {" "}
                              <Box as="span" color="label">| Est. Time: </Box>
                              <Box as="span" color={estimated_scan_time < 0 ? "bad" : "good"}>
                                {formatTime(estimated_scan_time)}
                              </Box>
                            </Box>
                          </Stack.Item>
                          <Stack.Item>
                            <Box fontSize="12px" color="label">
                              Possible: {possible_planets?.length || 0} planet type{possible_planets?.length !== 1 ? 's' : ''}
                            </Box>
                          </Stack.Item>
                        </Stack>
                      </Stack.Item>
                      {possible_planets && possible_planets.length > 0 && (
                        <Stack.Item>
                          <Box fontSize="11px" color="label" mt={0.5}>
                            {possible_planets.join(', ')}
                          </Box>
                        </Stack.Item>
                      )}
                      {possible_planets && possible_planets.length === 0 && (
                        <Stack.Item>
                          <Box fontSize="11px" color="bad" mt={0.5}>
                            No planets match these filters!
                          </Box>
                        </Stack.Item>
                      )}
                    </Stack>
                  </Section>
                </Stack.Item>
              )}

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
                      <Stack.Item width="280px">
                        <Box textAlign="center">
                          <Box
                            as="img"
                            src={currentPlanet ? `data:image/png;base64,${currentPlanet.icon_data}` : undefined}
                            height="256px"
                            width="256px"
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
                            <Box mb={2} fontSize="14px">
                              {currentPlanet ? currentPlanet.desc : 'No planet data available.'}
                            </Box>
                          </Stack.Item>
                          {currentPlanet && (currentPlanet.actual_heat || currentPlanet.actual_humidity || currentPlanet.actual_terrain || currentPlanet.actual_atmosphere) && (
                            <Stack.Item>
                              <Box mb={1} fontSize="12px" color="label">
                                <Stack wrap>
                                  {currentPlanet.actual_heat && (
                                    <Stack.Item mr={2}>
                                      <Box inline bold>Heat:</Box> {getLabel(HEAT_OPTIONS, currentPlanet.actual_heat)}
                                    </Stack.Item>
                                  )}
                                  {currentPlanet.actual_humidity && (
                                    <Stack.Item mr={2}>
                                      <Box inline bold>Humidity:</Box> {getLabel(HUMIDITY_OPTIONS, currentPlanet.actual_humidity)}
                                    </Stack.Item>
                                  )}
                                  {currentPlanet.actual_terrain && (
                                    <Stack.Item mr={2}>
                                      <Box inline bold>Terrain:</Box> {getLabel(TERRAIN_OPTIONS, currentPlanet.actual_terrain)}
                                    </Stack.Item>
                                  )}
                                  {currentPlanet.actual_atmosphere && (
                                    <Stack.Item mr={2}>
                                      <Box inline bold>Atmosphere:</Box> {getLabel(ATMOSPHERE_OPTIONS, currentPlanet.actual_atmosphere)}
                                    </Stack.Item>
                                  )}
                                </Stack>
                              </Box>
                            </Stack.Item>
                          )}
                          {currentPlanet && currentPlanet.beacons && currentPlanet.beacons.length > 0 && (
                            <Stack.Item>
                              <Box mb={1} fontSize="14px" bold>
                                Active Trackers:
                              </Box>
                              {currentPlanet.beacons.map((beacon, index) => (
                                <Box
                                  key={index}
                                  fontSize="12px"
                                  color={beacon.active ? "bad" : "label"}
                                  bold={beacon.active}
                                  mb={0.5}
                                >
                                  {beacon.active ? "🚨 " : ""}{beacon.tag}
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
                                  content="Print Destination Disk"
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
                        : possible_planets?.length === 0
                        ? "No planets match filters"
                        : "Start Planet Scan"
                    }
                    disabled={!can_scan || (possible_planets?.length === 0)}
                    onClick={() => act('start_scan')}
                    tooltip={
                      other_scan_in_progress
                        ? "A planet scan is already in progress on this station - multiple scans are disabled due to electrical infetterence."
                        : at_scan_limit
                        ? "Maximum scans reached"
                        : possible_planets?.length === 0
                        ? "No planets match the current filters"
                        : `Requires ${required_energy?.toLocaleString() || 0} J (${filter_cost_multiplier?.toFixed(2) || 1}x base) | Est: ${formatTime(estimated_scan_time)}`
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
