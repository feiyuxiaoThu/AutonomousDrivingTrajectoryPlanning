function [trajectory, isFeasible] = PlanSCPTrajectory(initialguess, collision_choice)
    %% Nonlinear kinematics equations are not treated, and the vehicle is covered with a circle
    % input: initialguess is required for optimal solution, this can be provided by the path found by A*.
    % collision_choice�� 1-convex feasible set (CFS); 2-box;
    % output:
    % trajectory.x,trajectory.y,trajectory.theta,trajectory.v,trajectory.phi
    % isFeasible: The output is 1 if the solver can find a feasible solution and 0 otherwise

    global planning_scale_ vehicle_geometrics_ vehicle_kinematics_ vehicle_TPBV_ obstacles_ Nobs margin_obs_
    isFeasible = 0;
    Lm = vehicle_geometrics_.vehicle_wheelbase;
    o_margin = margin_obs_; %0.5
    nobj = Nobs;
    obj = [];

    for i = 1:Nobs
        obj = [obj; obstacles_{i}.x; obstacles_{i}.y];
    end

    % Assign initial value to solver
    nstep = length(initialguess.x); 
    tf0 = nstep;
    refpath_vec = zeros(2 * nstep, 1);
    refpath_vec(1:2:end) = initialguess.x';
    refpath_vec(2:2:end) = initialguess.y';
    theta0 = initialguess.theta'; theta = theta0;
    v0 = initialguess.v'; vel = v0;
    phi0 = initialguess.phi'; phi = phi0;
    x0 = [refpath_vec; theta0; v0; phi0; tf0];
    path_k = refpath_vec;
    Ts = x0(5 * nstep + 1) / (nstep - 1); %delta_t

 
    dim = 2;
    num_dv = nstep * 5 + 1; %xn(2*nstep),theta(nstep),v(nstep),phi(nstep),tf(1)
 
    num_collision_max = nstep * nobj;

    Apdyn = zeros(nstep - 1, dim * nstep);
    Aqdyn = zeros(nstep - 1, dim * nstep);
    Athetadyn = zeros(nstep - 1, nstep);

    Av1 = zeros(nstep - 1, num_dv);
    Av2 = zeros(nstep - 1, num_dv);
    Aphi1 = zeros(nstep - 1, num_dv);
    Aphi2 = zeros(nstep - 1, num_dv);

    Obj1 = zeros(nstep - 1, num_dv);
    Obj2 = zeros(nstep - 1, num_dv);

    for k = 1:nstep - 1
        Obj1(k, 3 * nstep + k:3 * nstep + k + 1) = [-1, 1];
        Obj2(k, 4 * nstep + k:4 * nstep + k + 1) = [-1, 1];
   
        Apdyn(k, 2 * k - 1:2 * k + 1) = [-1, 0, 1];
        Aqdyn(k, 2 * k:2 * k + 2) = [-1, 0, 1];
        Athetadyn(k, k:k + 1) = [-1, 1];
  
        index1 = [3 * nstep + k:3 * nstep + k + 1, num_dv];
        index2 = [4 * nstep + k:4 * nstep + k + 1, num_dv];
        Av1(k, index1) = [-1, 1, -vehicle_kinematics_.vehicle_a_max / (nstep - 1)];
        Av2(k, index1) = [1, -1, -vehicle_kinematics_.vehicle_a_max / (nstep - 1)];
        Aphi1(k, index2) = [-1, 1, -vehicle_kinematics_.vehicle_omega_max / (nstep - 1)];
        Aphi2(k, index2) = [1, -1, -vehicle_kinematics_.vehicle_omega_max / (nstep - 1)];
    end

 
    f = zeros(num_dv, 1);
    f(end) = 1; % Minimize time
  
    H = 2 * (Obj1' * Obj1 + Obj2' * Obj2);
    H_x = 2 * (Obj1(:, 1:num_dv)' * Obj1(:, 1:num_dv) + Obj2(:, 1:num_dv)' * Obj2(:, 1:num_dv));

    %% Equation constraint: constrains the starting and ending states of the trajectory x,y,theta,v,phi
    Aeq0 = zeros(10, num_dv);
    beq0 = zeros(10, 1); %[refpath_vec(1);refpath_vec(2);refpath_vec(nstep*dim-1);refpath_vec(nstep*dim);refpath_vec(3)-refpath_vec(1);refpath_vec(4)-refpath_vec(2);refpath_vec(end-1)-refpath_vec(end-3);refpath_vec(end)-refpath_vec(end-2)];
    Aeq0(1:2, 1:2) = eye(2); %initial_x;initial_y
    Aeq0(3:4, nstep * 2 - 1:nstep * 2) = eye(2); %end_x;end_y
    Aeq0(5, nstep * 2 + 1) = 1; %initial_theta
    Aeq0(6, nstep * 3) = 1; %end_theta
    Aeq0(7, nstep * 3 + 1) = 1; %initial_v
    Aeq0(8, nstep * 4) = 1; %end_v
    Aeq0(9, nstep * 4 + 1) = 1; %initial_phi
    Aeq0(10, nstep * 5) = 1; %end_phi
    beq0(1:2) = [vehicle_TPBV_.x0; vehicle_TPBV_.y0]; %initial_x;initial_y
    beq0(3:4) = [vehicle_TPBV_.xtf; vehicle_TPBV_.ytf]; %end_x;end_y
    beq0(5) = vehicle_TPBV_.theta0;
    beq0(6) = vehicle_TPBV_.thetatf;
    beq0(7) = vehicle_TPBV_.v0;
    beq0(8) = vehicle_TPBV_.vtf;
    beq0(9) = vehicle_TPBV_.phi0;
    beq0(10) = vehicle_TPBV_.phitf;

    %% Boundary condition constraints
    lb = zeros(num_dv, 1);
    ub = zeros(num_dv, 1);
    % Range limits for trajectory horizontal and vertical coordinates
    lb(1:dim:dim * nstep) = planning_scale_.xmin;
    lb(2:dim:dim * nstep) = planning_scale_.ymin;
    ub(1:dim:dim * nstep) = planning_scale_.xmax;
    ub(2:dim:dim * nstep) = planning_scale_.ymax;
    % upper and lower bounds for theta 
    lb(2 * nstep + 1:3 * nstep) = -Inf;
    ub(2 * nstep + 1:3 * nstep) = Inf;
    % Upper and lower bounds of v
    lb(3 * nstep + 1:4 * nstep) = vehicle_kinematics_.vehicle_v_min;
    ub(3 * nstep + 1:4 * nstep) = vehicle_kinematics_.vehicle_v_max;
    % Upper and lower boundaries of phi
    lb(4 * nstep + 1:5 * nstep) = vehicle_kinematics_.vehicle_phi_min;
    ub(4 * nstep + 1:5 * nstep) = vehicle_kinematics_.vehicle_phi_max;
    % Upper and lower boundaries of travel time
    lb(5 * nstep + 1) = 0;
    ub(5 * nstep + 1) = 1000;
    % Equation penalties
    lb(num_dv + 1:end) = 0; %lb(num_dv+1:end)=-inf;
    ub(num_dv + 1:end) = inf;


%     F_x0 = [Apdyn * x0(1:2 * nstep) - Ts * vel(1:nstep - 1) .* cos(theta(1:nstep - 1)); Aqdyn * x0(1:2 * nstep) - Ts * vel(1:nstep - 1) .* sin(theta(1:nstep - 1)); Athetadyn * theta(1:nstep) - Ts / Lm * vel(1:nstep - 1) .* tan(phi(1:nstep - 1))];


    %% Start of iteration
    maxiter = 20;
    for k = 1:maxiter
       % Obstacle avoidance constraints
        A = zeros(num_collision_max, num_dv);
        b = zeros(num_collision_max, 1);

        counter_collision = 1; 
   
        for i = 1:nstep
            indexi = (i - 1) * dim + 1:i * dim;
            xnr = path_k(indexi); % xnr is a column vector
            % Compute the convex feasible set for xnr
            if collision_choice == 1
                [tempA, tempb] = FindBox(xnr);
            elseif collision_choice == 2
                [tempA, tempb, ~] = FindCFS(xnr, obj);
            end

            num_tempA = length(tempb);
            A(counter_collision:counter_collision - 1 + num_tempA, 2 * (i - 1) + 1:2 * i) = tempA;

            if collision_choice == 1
                b(counter_collision:counter_collision - 1 + num_tempA) = tempb;
            elseif collision_choice == 2
                b(counter_collision:counter_collision - 1 + num_tempA) = tempb - o_margin;
            end

            counter_collision = counter_collision + num_tempA;
        end

        num_collision = counter_collision - 1;
        num_constraint = num_collision + 4 * (nstep - 1);
        Aineq = zeros(num_constraint, num_dv);
        bineq = zeros(num_constraint, 1);

        %% Outer loops are CFS loops, inner loops are loops optimized for a fixed convex feasible set
        Aineq(1:num_collision, :) = A(1:num_collision, :);
        Aineq(num_collision + 1:num_collision + nstep - 1, :) = Av1;
        Aineq(num_collision + nstep:num_collision + 2 * (nstep - 1), :) = Av2;
        Aineq(num_collision + 2 * (nstep - 1) + 1:num_collision + 3 * (nstep - 1), :) = Aphi1;
        Aineq(num_collision + 3 * (nstep - 1) + 1:num_collision + 4 * (nstep - 1), :) = Aphi2;

        bineq(1:num_collision) = b(1:num_collision);

        x_last = x0;
        
        fun = @(x)1/2 * x' * H_x * x + f' * x;
        nonlcon = @(x)kinematiccon(x, nstep, Apdyn, Aqdyn, Athetadyn, Lm);
        options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp');
        [x, ~, exitflag, ~] = fmincon(fun, x0, Aineq(1:num_collision + 4 * (nstep - 1), 1:num_dv), bineq(1:num_collision + 4 * (nstep - 1)), Aeq0(:, 1:num_dv), beq0, lb(1:num_dv), ub(1:num_dv), nonlcon, options);
        if isempty(x) || exitflag == -2
            isFeasible = 0;
            x = [refpath_vec; theta0; v0; phi0; tf0];
            break;
        else 
            x0 = x;
        end

        if norm(x-x_last, 2) < 1e-4
             break;
        end
    end


    %% Determine whether the trajectory found in maxiter iterations satisfies the kinematic and obstacle avoidance constraints (whether a feasible solution is actually found)
    if isFeasible
        if sum(lb - x) <= 0 && sum(x - ub) <= 0 && sum(Aineq * x - bineq) <= 0 && sum(abs(Aeq0 * x - beq0)) <= 0.1
            isFeasible = 1;
        else
            isFeasible = 0;
        end
    end

     %% Constraint checking of the resulting solution again
    if isFeasible == 1
        if norm(kinematiccon(x, nstep, Apdyn, Aqdyn, Athetadyn, Lm)) < 1e-3 && sum(lb(1:num_dv) - x) <= 0 ...
                && sum(x - ub) <= 0 && sum(Aineq * x - bineq) <= 0 ...
                && sum(abs(Aeq0 * x - beq0)) <= 0.1
            isFeasible = 1;
        else
            isFeasible = 0;
        end

    end

    trajectory.x = x(1:2:dim * nstep);
    trajectory.y = x(2:2:dim * nstep);
    trajectory.theta = x(2 * nstep + 1:3 * nstep);
    trajectory.v = x(3 * nstep + 1:4 * nstep);
    trajectory.phi = x(4 * nstep + 1:5 * nstep);
    trajectory.tf = x(5 * nstep + 1);

end

function [c, ceq] = kinematiccon(x, nstep, Apdyn, Aqdyn, Athetadyn, Lm)
    c = [];
    theta = x(2 * nstep + 1:3 * nstep);
    vel = x(3 * nstep + 1:4 * nstep);
    phi = x(4 * nstep + 1:5 * nstep);
    Ts = x(5 * nstep + 1) / (nstep - 1);
    ceq = [Apdyn * x(1:2 * nstep) - Ts * vel(1:nstep - 1) .* cos(theta(1:nstep - 1)); Aqdyn * x(1:2 * nstep) - Ts * vel(1:nstep - 1) .* sin(theta(1:nstep - 1)); Athetadyn * theta(1:nstep) - Ts / Lm * vel(1:nstep - 1) .* tan(phi(1:nstep - 1))];
end

%% Find Box for all obstacles
function [A, b] = FindBox(xr)
     % xr:2*1, for the point
    [xc, yc] = SpinTrial(xr(1), xr(2));
    lb = GetAabbLength(xc, yc);
    bxmax = max(xc + lb(4), xc - lb(2)); bxmin = min(xc + lb(4), xc - lb(2));
    bymax = max(yc + lb(1), yc - lb(3)); bymin = min(yc + lb(1), yc - lb(3));
    A = [1 0; -1 0; 0 1; 0 -1];
    b = [bxmax; -bxmin; bymax; -bymin];

    function [xc, yc] = SpinTrial(xc, yc)

        if (IsPointValidInDilatedMap(xc, yc))
            return;
        end

        global hybrid_astar_
        unit_length = hybrid_astar_.resolution_x * 0.5;
        ii = 0;

        while (1)
            ii = ii + 1;
            angle_type = mod(ii, 8);
            radius = 1 + (ii - angle_type) / 8;
            angle = angle_type * pi / 4;
            x_nudge = xc + cos(angle) * radius * unit_length;
            y_nudge = yc + sin(angle) * radius * unit_length;

            if (IsPointValidInDilatedMap(x_nudge, y_nudge))
                xc = x_nudge;
                yc = y_nudge;
                return;
            end

        end

    end

    function is_valid = IsPointValidInDilatedMap(x, y)
        is_valid = 0;
        global planning_scale_ hybrid_astar_ costmap_
        ind_x = floor((x - planning_scale_.xmin) / hybrid_astar_.resolution_x) + 1;
        ind_y = floor((y - planning_scale_.ymin) / hybrid_astar_.resolution_y) + 1;

        if ((ind_x < 1) || (ind_x > hybrid_astar_.num_nodes_x) || (ind_y < 1) || (ind_y > hybrid_astar_.num_nodes_y))
            return;
        end

        if (costmap_(sub2ind(size(costmap_), ind_x, ind_y)))
            return;
        end

        is_valid = 1;
    end

    function lb = GetAabbLength(xc, yc)
        global params_
        params_.opti.stc.ds = 0.5; %0.1
        params_.opti.stc.smax = 5; %2

        lb = zeros(1, 4);

        is_completed = zeros(1, 4);

        while (sum(is_completed) < 4)

            for ind = 1:4

                if (is_completed(ind))
                    continue;
                end

                test = lb;

                if (test(ind) + params_.opti.stc.ds > params_.opti.stc.smax)
                    is_completed(ind) = 1;
                    continue;
                end

                test(ind) = test(ind) + params_.opti.stc.ds;

                if (IsCurrentExpansionValid(xc, yc, test, lb, ind))
                    lb = test;
                else
                    is_completed(ind) = 1;
                end

            end

        end

    end

    function is_valid = IsCurrentExpansionValid(xc, yc, test, lb, ind)
        is_valid = 0;

        ax = xc - lb(2); ay = yc + lb(1);
        bx = xc + lb(4); by = yc + lb(1);
        cx = xc + lb(4); cy = yc - lb(3);
        dx = xc - lb(2); dy = yc - lb(3);

        global hybrid_astar_ planning_scale_ vehicle_geometrics_ costmap_
        ds = hybrid_astar_.resolution_x * 0.5;

        switch ind
            case 1
                xmax = bx; xmin = ax; ymin = ay; ymax = yc + test(1);
            case 2
                xmax = ax; xmin = xc - test(2); ymin = dy; ymax = ay;
            case 3
                xmax = cx; xmin = dx; ymin = yc - test(3); ymax = cy;
            case 4
                xmax = xc + test(4); xmin = cx; ymin = cy; ymax = by;
            otherwise
                return;
        end

        if ((xmax > planning_scale_.xmax - vehicle_geometrics_.radius) || ...
                (xmin < planning_scale_.xmin + vehicle_geometrics_.radius) || ...
                (ymax > planning_scale_.ymax - vehicle_geometrics_.radius) || ...
                (ymin < planning_scale_.ymin + vehicle_geometrics_.radius))
            return;
        end

        xx = [];
        yy = [];
        nx = ceil((xmax - xmin) / ds) + 1;
        ny = ceil((ymax - ymin) / ds) + 1;

        for x = linspace(xmin, xmax, nx)

            for y = linspace(ymin, ymax, ny)
                xx = [xx, x];
                yy = [yy, y];
            end

        end

        ind_x = floor((xx - planning_scale_.xmin) / hybrid_astar_.resolution_x) + 1;
        ind_y = floor((yy - planning_scale_.ymin) / hybrid_astar_.resolution_y) + 1;

        if (any(costmap_(sub2ind(size(costmap_), ind_x, ind_y))))
            return;
        end

        is_valid = 1;
    end

end

%% Find CFS for all obstacles
function [A, b, d] = FindCFS(xr, obstacle)
    % the point xr:2*1, obstacle 2n*4
    ncorner = size(obstacle, 2); %the number of vertices in the obstacles (4)
    nobj = size(obstacle, 1) / 2;
    d = inf * ones(nobj, 1); 
    % (aTx<=b):pre_A,pre_b
    pre_A = zeros(nobj, 2);
    pre_b = zeros(nobj, 1);
    counter = 0;
    index_true = ones(nobj, 1); % index_true(j)=0 means the jth line is excluded
    % After determining the function phi, F(xr) is: phi(xr) + delta_phi(xr)*(x-xr)>=0
    for j = 1:nobj
        counter = counter + 1;
        obj = obstacle(2 * j - 1:2 * j, :);

        for i = 1:ncorner
            corner1 = obj(:, i);
            corner2 = obj(:, mod(i, ncorner) + 1);
             % xr,corner1 and corner2 form a triangle and find the lengths of the three sides
            dist_r1 = norm(xr - corner1);
            dist_r2 = norm(xr - corner2);
            dist_12 = norm(corner1 - corner2);
            % If angle r12 is obtuse, then xr is closer to corner1 at this point
            if (dist_r1^2 + dist_12^2 - dist_r2^2) < -1e-4 % Cosine Theorem
                temp_d = dist_r1;
                temp_A = xr' - corner1';
                temp_b = temp_A * corner1;
            elseif (dist_r2^2 + dist_12^2 - dist_r1^2) < -1e-4 % If angle r21 is obtuse, then xr is closer to corner2 at this point
                temp_d = dist_r2;
                temp_A = xr' - corner2';
                temp_b = temp_A * corner2;
            else
                % If angle r12 and angle r21 are both acute, then the vertical line from xr to the segment of the line formed by corner1 and corner2 is the shortest
                project_length = (xr - corner1)' * (corner2 - corner1) / dist_12;
                temp_d = sqrt(dist_r1^2 - project_length^2);
                temp_A = [corner1(2) - corner2(2), corner2(1) - corner1(1)];
                temp_b = corner2(1) * corner1(2) - corner1(1) * corner2(2);
            end

            if temp_d < d(j)
                d(j) = temp_d;
                single_A = temp_A;
                single_b = temp_b;
            end

        end

        length_A = norm(single_A);
        single_A = single_A / length_A;
        single_b = single_b / length_A;

        % the diagonal point of the vertex nearest to xr, which should be on either side of the line Ax = b with xr
        for kkk = 1:ncorner

            if single_A * obj(:, kkk) < single_b
                single_A = -single_A;
                single_b = -single_b;
                break;
            end

        end

        pre_A(counter, :) = single_A;
        pre_b(counter, :) = single_b;

    end

    % See if there are redundant constraints in pre_A and pre_b
    % Above, each obstacle corresponds to finding a straight line dividing xr and the obstacle itself. 
    % If excluding this line leaves a line that still splits this obstacle and xr, then this line can indeed be excluded from the constraint
    for j = 1:nobj
        temp_index = index_true;
        temp_index(j) = 0;
        cur_index = find(temp_index > 0);
        cur_A = pre_A(cur_index, :);
        cur_b = pre_b(cur_index);
        obj = obstacle(2 * j - 1:2 * j, :);

        result = cur_A * obj - repmat(cur_b, 1, 4);
        flag = sum(result >= 0, 2);

        if ~isempty(find(flag >= 4, 1))
            index_true(j) = 0;
        end

    end

    final_index = find(index_true > 0);
    A = pre_A(final_index, :);
    b = pre_b(final_index);
end
