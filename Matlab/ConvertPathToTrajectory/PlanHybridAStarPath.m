function [x, y, theta, path_length, completeness_flag] = PlanHybridAStarPath()
global costmap_
costmap_ = CreateDilatedCostmap();
global hybrid_astar_ vehicle_TPBV_ vehicle_kinematics_
grid_space_ = cell(hybrid_astar_.num_nodes_x, hybrid_astar_.num_nodes_y, hybrid_astar_.num_nodes_theta);
end_config = [vehicle_TPBV_.xtf, vehicle_TPBV_.ytf, vehicle_TPBV_.thetatf];
start_config = [vehicle_TPBV_.x0, vehicle_TPBV_.y0, vehicle_TPBV_.theta0];
goal_ind = Convert3DimConfigToIndex(end_config);
init_node = zeros(1,16);
% Information of each element in each node:
% Dim # | Variable
%  1        x
%  2        y
%  3        theta
%  4        f
%  5        g
%  6        h
%  7        is_in_openlist
%  8        is_in_closedlist
%  9-11     index of current node
%  12-14    index of parent node
%  15-16    expansion operation [v,phi] that yields the current node

init_node(1:3) = start_config;
init_node(6) = CalculateH(start_config, end_config);
init_node(5) = 0;
init_node(4) = init_node(5) + hybrid_astar_.multiplier_H * init_node(6);
init_node(7) = 1;
init_node(9:11) = Convert3DimConfigToIndex(start_config);
init_node(12:14) = [-999,-999,-999];
openlist_ = init_node;

grid_space_{init_node(9), init_node(10), init_node(11)} = init_node;
expansion_pattern = [1, -vehicle_kinematics_.vehicle_phi_max; 1, 0; 1, vehicle_kinematics_.vehicle_phi_max; -1, -vehicle_kinematics_.vehicle_phi_max; -1, 0; -1, vehicle_kinematics_.vehicle_phi_max];
completeness_flag = 0;
complete_via_rs_flag = 0;
best_ever_val = Inf;
best_ever_ind = init_node(9:11);
path_length = 0;
iter = 0;

tic
while ((~isempty(openlist_)) && (iter <= hybrid_astar_.max_iter) && (~completeness_flag) && (toc <= hybrid_astar_.max_time))
    iter = iter + 1;
    cur_node_order = find(openlist_(:,4) == min(openlist_(:,4))); cur_node_order = cur_node_order(end);
    cur_node = openlist_(cur_node_order, :);
    cur_config = cur_node(1:3);
    cur_ind = cur_node(9:11);
    cur_g = cur_node(5);
    cur_v = cur_node(15);
    cur_phi = cur_node(16);
    % Specify analytical RS curve generator is activated.
    if (mod(iter-1, hybrid_astar_.Nrs) == 0)
        [x_rs, y_rs, theta_rs, path_length] = GenerateRsPath(cur_config, end_config);
        if (Is3DNodeValid([x_rs, y_rs, theta_rs]))
            completeness_flag = 1;
            complete_via_rs_flag = 1;
            best_ever_ind = cur_ind;
            break;
        end
    end
    % Remove cur_node from openlist and add it in closed list
    openlist_(cur_node_order, :) = [];
    grid_space_{cur_ind(1), cur_ind(2), cur_ind(3)}(7) = 0;
    grid_space_{cur_ind(1), cur_ind(2), cur_ind(3)}(8) = 1;
    % Expand the current node to its 6 children
    for ii = 1 : 6
        child_node_v = expansion_pattern(ii,1);
        child_node_phi = expansion_pattern(ii,2);
        child_node_config = SimulateForUnitDistance(cur_config, child_node_v, child_node_phi, hybrid_astar_.simulation_step);
        child_node_ind = Convert3DimConfigToIndex(child_node_config);
        % If the child node has been explored ever before, and it has been closed:
        if ((~isempty(grid_space_{child_node_ind(1), child_node_ind(2), child_node_ind(3)})) && (grid_space_{child_node_ind(1), child_node_ind(2), child_node_ind(3)}(8) == 1))
            continue;
        end
        child_g = cur_g + hybrid_astar_.simulation_step + hybrid_astar_.penalty_for_direction_changes * abs(cur_v - child_node_v) + hybrid_astar_.penalty_for_steering_changes * abs(cur_phi - child_node_phi);
        
        % Now, if the child node has been explored ever before, and it is still in the openlist:
        if (~isempty(grid_space_{child_node_ind(1), child_node_ind(2), child_node_ind(3)}))
            % If the previously found parent of the child is not good enough, a change is to be made
            if (grid_space_{child_node_ind(1), child_node_ind(2), child_node_ind(3)}(5) > child_g + 0.1)
                child_node_order1 = find(openlist_(:,9) == child_node_ind(1));
                child_node_order2 = find(openlist_(child_node_order1,10) == child_node_ind(2));
                child_node_order3 = find(openlist_(child_node_order1(child_node_order2),11) == child_node_ind(3));
                openlist_(child_node_order1(child_node_order2(child_node_order3)), :) = [];
                child_node_update = grid_space_{child_node_ind(1),child_node_ind(2),child_node_ind(3)};
                child_node_update(5) = child_g;
                child_node_update(4) = child_node_update(5) + hybrid_astar_.multiplier_H * child_node_update(6);
                child_node_update(12:14) = cur_ind;
                child_node_update(15:16) = [child_node_v, child_node_phi];
                openlist_ = [openlist_; child_node_update];
                grid_space_{child_node_ind(1),child_node_ind(2),child_node_ind(3)} = child_node_update;
            end
            continue;
        end
        
        child_node = zeros(1,16);
        % Now the child node is ensured to be newly expanded
        if (~Is3DNodeValid(child_node_config))
            child_node(8) = 1;
            grid_space_{child_node_ind(1),child_node_ind(2),child_node_ind(3)} = child_node;
            continue;
        end
        % We did not calculate H for the child node till now to avoid wasiting CPU.
        % Now the child node is both new and collision-free.
        child_node(1:3) = child_node_config;
        child_node(5) = child_g;
        child_node(6) = CalculateH(child_node_config, end_config);
        child_node(4) = child_node(5) + hybrid_astar_.multiplier_H * child_node(6);
        child_node(7) = 1;
        child_node(9:11) = child_node_ind;
        child_node(12:14) = cur_ind;
        child_node(15:16) = [child_node_v, child_node_phi];
        openlist_ = [openlist_; child_node];
        grid_space_{child_node_ind(1),child_node_ind(2),child_node_ind(3)} = child_node;
        % Failure-safe solution preparation
        if (child_node(6) < best_ever_val)
            best_ever_val = child_node(6);
            best_ever_ind = child_node_ind;
        end
        % If child node is the goal node
        if (~any(child_node_ind - goal_ind))
            completeness_flag = 1;
            best_ever_ind = goal_ind;
            break;
        end
    end
end

% Output hybrid A* path
cur_best_parent_ind = grid_space_{best_ever_ind(1), best_ever_ind(2), best_ever_ind(3)}(12:14);
x = grid_space_{best_ever_ind(1), best_ever_ind(2), best_ever_ind(3)}(1);
y = grid_space_{best_ever_ind(1), best_ever_ind(2), best_ever_ind(3)}(2);
theta = grid_space_{best_ever_ind(1), best_ever_ind(2), best_ever_ind(3)}(3);

while (cur_best_parent_ind(1) > -1)
    path_length = path_length + hybrid_astar_.simulation_step;
    cur_node = grid_space_{cur_best_parent_ind(1), cur_best_parent_ind(2), cur_best_parent_ind(3)};
    cur_best_parent_ind = cur_node(12:14);
    x = [cur_node(1), x];
    y = [cur_node(2), y];
    theta = [cur_node(3), theta];
end
if (completeness_flag)
    if (complete_via_rs_flag)
        x_rs = x_rs';
        y_rs = y_rs';
        theta_rs = theta_rs';
        if (size(x_rs, 2) > 1)
            x = [x, x_rs(2:end)];
            y = [y, y_rs(2:end)];
            theta = [theta, theta_rs(2:end)];
        end
    else
        x = [x, end_config(1)];
        y = [y, end_config(2)];
        theta = [theta, end_config(3)];
    end
end
if (completeness_flag)
    [x, y, theta] = ResamplePathWithEqualDistance(x, y, theta);
    path_length = 0;
    for ii = 1 : (length(x) - 1)
        path_length = path_length + hypot(x(ii+1) - x(ii), y(ii+1) - y(ii));
    end
end
end

function child_node_config = SimulateForUnitDistance(cur_config, v, phi, simulation_step)
global vehicle_geometrics_
Nfe = 10;
hi = simulation_step / Nfe;
theta = cur_config(3); x = cur_config(1); y = cur_config(2);
for ii = 1 : Nfe
    x = cos(theta) * v * hi + x;
    y = sin(theta) * v * hi + y;
    theta = tan(phi) * v / vehicle_geometrics_.vehicle_wheelbase  * hi + theta;
end
child_node_config = [x,y,theta];
end

function is_collision_free = Is3DNodeValid(child_node_config)
is_collision_free = 0;
global vehicle_geometrics_ planning_scale_ hybrid_astar_ costmap_
xr = child_node_config(:,1) + vehicle_geometrics_.r2x * cos(child_node_config(:,3));
yr = child_node_config(:,2) + vehicle_geometrics_.r2x * sin(child_node_config(:,3));
xf = child_node_config(:,1) + vehicle_geometrics_.f2x * cos(child_node_config(:,3));
yf = child_node_config(:,2) + vehicle_geometrics_.f2x * sin(child_node_config(:,3));
xx = [xr; xf];
yy = [yr; yf];
if (sum(xx > planning_scale_.xmax - vehicle_geometrics_.radius * 1.01))
    return;
elseif (sum(xx < planning_scale_.xmin + vehicle_geometrics_.radius * 1.01))
    return;
elseif (sum(yy > planning_scale_.ymax - vehicle_geometrics_.radius * 1.01))
    return;
elseif (sum(yy < planning_scale_.ymin + vehicle_geometrics_.radius * 1.01))
    return;
end
indx = round((xx - planning_scale_.xmin) /  hybrid_astar_.resolution_x + 1);
indy = round((yy - planning_scale_.ymin) /  hybrid_astar_.resolution_y + 1);
if (sum(costmap_(sub2ind(size(costmap_),indx,indy))))
    return;
end
is_collision_free = 1;
end

function val = CalculateH(start_config, end_config)
distance_nonholonomic_without_collision_avoidance = max(norm(start_config(1:2) - end_config(1:2)), CalculateRsPathLength(start_config, end_config));
distance_holonomic_with_collision_avoidance = CalculateAStarPathLength(start_config, end_config);
val = max(distance_nonholonomic_without_collision_avoidance, distance_holonomic_with_collision_avoidance);
end

function path_length = CalculateRsPathLength(start_config, end_config)
global vehicle_kinematics_ hybrid_astar_
reedsConnObj = robotics.ReedsSheppConnection('MinTurningRadius', vehicle_kinematics_.min_turning_radius);
reedsConnObj.ReverseCost = hybrid_astar_.penalty_for_backward;
[pathSegObj, ~] = connect(reedsConnObj, start_config, end_config);
path_length = pathSegObj{1}.Length;
end

function path_length = CalculateAStarPathLength(start_config, end_config)
global hybrid_astar_
begin_config = start_config(1:2);
end_config = end_config(1:2);
grid_space_2D_ = cell(hybrid_astar_.num_nodes_x, hybrid_astar_.num_nodes_y);
init_node = zeros(1,11);
% Information of each element in each node:
% Dim # | Variable
%  1        x
%  2        y
%  3        f
%  4        g
%  5        h
%  6        is_in_openlist
%  7        is_in_closedlist
%  8-9      index of current node
%  10-11    index of parent node

init_node(1:2) = begin_config;
init_node(4) = 0;
init_node(5) = sum(abs(init_node(1:2) - end_config));
init_node(3) = init_node(4) + hybrid_astar_.multiplier_H_for_A_star * init_node(5) + 0.001 * randn;
init_node(6) = 1;
init_node(8:9) = Convert2DimConfigToIndex(begin_config);
init_node(10:11) = [-999,-999];
openlist_ = init_node;
goal_ind = Convert2DimConfigToIndex(end_config);
grid_space_2D_{init_node(8), init_node(9)} = init_node;
expansion_pattern = [-1 1; -1 0; -1 -1; 0 1; 0 -1; 1 1; 1 0; 1 -1] .* hybrid_astar_.resolution_x;
expansion_length = [1.414; 1; 1.414; 1; 1; 1.414; 1; 1.414] .* hybrid_astar_.resolution_x;
iter = 0;

while ((~isempty(openlist_))&&(iter <= hybrid_astar_.num_nodes_x^2))
    iter = iter + 1;
    % Locate the node with smallest f value in the openlist, and then name
    % it as cur_node and prepare for extension
    cur_node_order = find(openlist_(:,3) == min(openlist_(:,3))); cur_node_order = cur_node_order(end);
    cur_node = openlist_(cur_node_order, :);
    cur_config = cur_node(1:2);
    cur_ind = cur_node(8:9);
    cur_g = cur_node(4);
    % Remove cur_node from open list and add it in closed list
    openlist_(cur_node_order, :) = [];
    grid_space_2D_{cur_ind(1), cur_ind(2)}(6) = 0;
    grid_space_2D_{cur_ind(1), cur_ind(2)}(7) = 1;
    for ii = 1 : 8
        child_node_config = cur_config + expansion_pattern(ii,:);
        child_node_ind = Convert2DimConfigToIndex(child_node_config);
        child_g = cur_g + expansion_length(ii);
        child_h = sum(abs(child_node_config - end_config));
        child_f = child_g + hybrid_astar_.multiplier_H_for_A_star * child_h;
        child_node_prepare = [child_node_config, child_f, child_g, child_h, 1, 0, child_node_ind, cur_ind];
        % If the child node has been explored ever before
        if (~isempty(grid_space_2D_{child_node_ind(1), child_node_ind(2)}))
            % If the child has been within the closed list, abandon it and continue.
            if (grid_space_2D_{child_node_ind(1), child_node_ind(2)}(7) == 1)
                continue;
            end
            % The child must be in the open list now, then check if its
            % recorded parent deserves to be switched as our cur_node.
            if (grid_space_2D_{child_node_ind(1), child_node_ind(2)}(4) > child_g + 0.1)
                child_node_order1 = find(openlist_(:,8) == child_node_ind(1));
                child_node_order2 = find(openlist_(child_node_order1,9) == child_node_ind(2));
                openlist_(child_node_order1(child_node_order2), :) = [];
                grid_space_2D_{child_node_ind(1), child_node_ind(2)} = child_node_prepare;
                openlist_ = [openlist_; child_node_prepare];
            end
        else % Child node has never been explored before
            % If the child node is collison free
            if (Is2DNodeValid(child_node_config, child_node_ind))
                % If the child node is close to the goal point, then exit
                % directly because we only need the length value rather than the path.
                openlist_ = [openlist_; child_node_prepare];
                grid_space_2D_{child_node_ind(1), child_node_ind(2)} = child_node_prepare;
                if (sum(abs(child_node_ind - goal_ind)) == 0)
                    path_length = child_g;
                    return;
                end
            else % If the child node involves collisons
                child_node_prepare(7) = 1;
                child_node_prepare(6) = 0;
                grid_space_2D_{child_node_ind(1), child_node_ind(2)} = child_node_prepare;
            end
        end
    end
end
path_length = sum(abs(begin_config - end_config));
end

function is_collision_free = Is2DNodeValid(child_node_config, child_node_ind)
is_collision_free = 1;
global planning_scale_ costmap_
if (costmap_(child_node_ind(1), child_node_ind(2)) == 1)
    is_collision_free = 0;
    return;
end
if ((child_node_config(1) > planning_scale_.xmax) || (child_node_config(1) < planning_scale_.xmin) || (child_node_config(2) > planning_scale_.ymax) || (child_node_config(2) < planning_scale_.ymin))
    is_collision_free = 0;
    return;
end
end

function idx = Convert3DimConfigToIndex(config)
global hybrid_astar_ planning_scale_
ind1 = ceil((config(1) - planning_scale_.xmin) / hybrid_astar_.resolution_x) + 1;
ind2 = ceil((config(2) - planning_scale_.ymin) / hybrid_astar_.resolution_y) + 1;
ind3 = ceil((RegulateAngle(config(3))) / hybrid_astar_.resolution_theta) + 1;
idx = [ind1, ind2, ind3];
if ((ind1 <= hybrid_astar_.num_nodes_x)&&(ind1 >= 1)&&(ind2 <= hybrid_astar_.num_nodes_y)&&(ind2 >= 1))
    return;
end
if (ind1 > hybrid_astar_.num_nodes_x)
    ind1 = hybrid_astar_.num_nodes_x;
elseif (ind1 < 1)
    ind1 = 1;
end
if (ind2 > hybrid_astar_.num_nodes_y)
    ind2 = hybrid_astar_.num_nodes_y;
elseif (ind2 < 1)
    ind2 = 1;
end
idx = [ind1, ind2, ind3];
end

function [x, y, theta, path_length] = GenerateRsPath(startPose, goalPose)
global vehicle_kinematics_ hybrid_astar_
reedsConnObj = robotics.ReedsSheppConnection('MinTurningRadius', vehicle_kinematics_.min_turning_radius);
reedsConnObj.ReverseCost = hybrid_astar_.penalty_for_backward;
[pathSegObj,~] = connect(reedsConnObj,startPose,goalPose);
path_length = pathSegObj{1}.Length;
poses = interpolate(pathSegObj{1},[0 : hybrid_astar_.resolution_x : path_length]);
x = poses(:,1);
y = poses(:,2);
theta = poses(:,3);
end

function angle  = RegulateAngle(angle)
while (angle > 2 * pi + 0.000001)
    angle = angle - 2 * pi;
end
while (angle < - 0.000001)
    angle = angle + 2 * pi;
end
end

function idx = Convert2DimConfigToIndex(config)
global hybrid_astar_ planning_scale_
ind1 = ceil((config(1) - planning_scale_.xmin) / hybrid_astar_.resolution_x) + 1;
ind2 = ceil((config(2) - planning_scale_.ymin) / hybrid_astar_.resolution_y) + 1;
idx = [ind1, ind2];
if ((ind1 <= hybrid_astar_.num_nodes_x)&&(ind1 >= 1)&&(ind2 <= hybrid_astar_.num_nodes_y)&&(ind2 >= 1))
    return;
end
if (ind1 > hybrid_astar_.num_nodes_x)
    ind1 = hybrid_astar_.num_nodes_x;
elseif (ind1 < 1)
    ind1 = 1;
end
if (ind2 > hybrid_astar_.num_nodes_y)
    ind2 = hybrid_astar_.num_nodes_y;
elseif (ind2 < 1)
    ind2 = 1;
end
idx = [ind1, ind2];
end

function costmap = CreateDilatedCostmap()
global planning_scale_ hybrid_astar_ vehicle_geometrics_ Nobs obstacles_
xmin = planning_scale_.xmin;
ymin = planning_scale_.ymin;
resolution_x = hybrid_astar_.resolution_x;
resolution_y = hybrid_astar_.resolution_y;
costmap = zeros(hybrid_astar_.num_nodes_x, hybrid_astar_.num_nodes_y);

for ii = 1 : Nobs 
    vx = obstacles_{ii}.x;
    vy = obstacles_{ii}.y;
    x_lb = min(vx); x_ub = max(vx); y_lb = min(vy); y_ub = max(vy);
    [Nmin_x,Nmin_y] = ConvertXYToIndex(x_lb,y_lb);
    [Nmax_x,Nmax_y] = ConvertXYToIndex(x_ub,y_ub);
    for jj = Nmin_x : Nmax_x
        for kk = Nmin_y : Nmax_y
            if (costmap(jj,kk) == 1)
                continue;
            end
            cur_x = xmin + (jj - 1) * resolution_x;
            cur_y = ymin + (kk - 1) * resolution_y;
            if (inpolygon(cur_x, cur_y, obstacles_{ii}.x, obstacles_{ii}.y) == 1)
                costmap(jj,kk) = 1;
            end
        end
    end
end
length_unit = 0.5 * (resolution_x + resolution_y);
basic_elem = strel('disk', ceil(vehicle_geometrics_.radius / length_unit));
costmap = imdilate(costmap, basic_elem);
end

function [ind1,ind2] = ConvertXYToIndex(x,y)
global hybrid_astar_ planning_scale_
ind1 = ceil((x - planning_scale_.xmin) / hybrid_astar_.resolution_x) + 1;
ind2 = ceil((y - planning_scale_.ymin) / hybrid_astar_.resolution_y) + 1;
if ((ind1 <= hybrid_astar_.num_nodes_x)&&(ind1 >= 1)&&(ind2 <= hybrid_astar_.num_nodes_y)&&(ind2 >= 1))
    return;
end
if (ind1 > hybrid_astar_.num_nodes_x)
    ind1 = hybrid_astar_.num_nodes_x;
elseif (ind1 < 1)
    ind1 = 1;
end
if (ind2 > hybrid_astar_.num_nodes_y)
    ind2 = hybrid_astar_.num_nodes_y;
elseif (ind2 < 1)
    ind2 = 1;
end
end

function [x, y, theta] = ResamplePathWithEqualDistance(x, y, theta)
for ii = 2 : length(theta)
    while (theta(ii) - theta(ii-1) > pi)
        theta(ii) = theta(ii) - 2 * pi;
    end
    while (theta(ii) - theta(ii-1) < -pi)
        theta(ii) = theta(ii) + 2 * pi;
    end
end
x_extended = [];
y_extended = [];
theta_extended = [];
for ii = 1 : (length(x) - 1)
    distance = hypot(x(ii+1)-x(ii), y(ii+1)-y(ii));
    LARGE_NUM = round(distance * 100);
    temp = linspace(x(ii), x(ii+1), LARGE_NUM);
    temp = temp(1,1:(LARGE_NUM - 1));
    x_extended = [x_extended, temp];
    
    temp = linspace(y(ii), y(ii+1), LARGE_NUM);
    temp = temp(1,1:(LARGE_NUM - 1));
    y_extended = [y_extended, temp];
    
    temp = linspace(theta(ii), theta(ii+1), LARGE_NUM);
    temp = temp(1,1:(LARGE_NUM - 1));
    theta_extended = [theta_extended, temp];
end
x_extended = [x_extended, x(end)];
y_extended = [y_extended, y(end)];
theta_extended = [theta_extended, theta(end)];
global num_nodes_s
index = round(linspace(1, length(x_extended), num_nodes_s));
x = x_extended(index);
y = y_extended(index);
theta = theta_extended(index);
end