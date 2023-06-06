function [trajectory, isFeasible] = PlanL1SCPTrajectory(initialguess, collision_choice)
    %% Nonlinear kinematics equations are treated with L1 norm, and the vehicle is covered with a circle
    % input: initialguess�Ż����ʱ��Ҫһ����ʼ�²⣬�˿���A*�ҵ���·���ṩ��
    % collision_choice�� 1-box; 2-convex feasible set (CFS);
    % output:
    % trajectory.x,trajectory.y,trajectory.theta,trajectory.v,trajectory.phi
    % isFeasible:  The output is 1 if the solver can find a feasible solution and 0 otherwise

    global planning_scale_ vehicle_geometrics_ vehicle_kinematics_ vehicle_TPBV_ obstacles_ Nobs margin_obs_
    isFeasible = 0;
    Lm = vehicle_geometrics_.vehicle_wheelbase;
    o_margin = margin_obs_; %0.5
    nobj = Nobs;
    obj = [];

    for i = 1:Nobs
        obj = [obj; obstacles_{i}.x; obstacles_{i}.y];
    end

    %% �����������ֵ
    nstep = length(initialguess.x); % nstep=��ɢ��ĸ���
    tf0 = nstep;
    refpath_vec = zeros(2 * nstep, 1);
    refpath_vec(1:2:end) = initialguess.x';
    refpath_vec(2:2:end) = initialguess.y';
    theta0 = initialguess.theta'; theta = theta0;
    v0 = initialguess.v'; vel = v0;
    phi0 = initialguess.phi'; phi = phi0;
    x0 = [refpath_vec; theta0; v0; phi0; tf0];
    path_k = refpath_vec;
    Ts = x0(5 * nstep + 1) / (nstep - 1); %����ʱ��delta_t

    % ���߱�������
    dim = 2;
    num_dv = nstep * 5 + 1; %С������λ��xn(2*nstep),theta(nstep),v(nstep),phi(nstep),tf(1)
    % ������������
    num_aux = 3 * nstep - 3;
    % ����Լ���������
    num_collision_max = nstep * nobj;

    %% �㷨��������
    % ����ֱ�������Ĳ���
    beta1 = 0.7;
    alpha1 = 0.3;
    step_size = 1;
    % �Ż��㷨���ò���
    iter = zeros(50, 1);
    alpha = 2.5;
    beta = 2.5;
    radius0 = 4;
    ratio = 3;
    inner_maxiter = 50; %�����ѭ������
    rho1 = 0.2;
    rho2 = 0.9;
    threshold_linear_error = 0.01;
    inner_counter = 3; %����inner_counter��û�иĽ�Ŀ�꺯��ֵ�����˳�ѭ��
    % ֹͣ��ֵ
    threshold = 1e-5;
    % ��ѭ������������
    maxiter = 5;
    % Ŀ�꺯���ͷ�Ȩ��
    lambda = 1e5; %1e5;
    % ����ֱ������merit function��Ȩ��
    mup = 1e3;
    % �������������
    radius_low = 1e-3; %��С��������뾶
    radius_up = 4.5; %����������뾶

    %% ��ɢ�����˶�ѧ����
    Apdyn = zeros(nstep - 1, dim * nstep);
    Aqdyn = zeros(nstep - 1, dim * nstep);
    Athetadyn = zeros(nstep - 1, nstep);

    %% ��ɢ�Ĵ���״̬����
    Av1 = zeros(nstep - 1, num_dv + num_aux);
    Av2 = zeros(nstep - 1, num_dv + num_aux);
    Aphi1 = zeros(nstep - 1, num_dv + num_aux);
    Aphi2 = zeros(nstep - 1, num_dv + num_aux);

    %% �µ�
    Obj1 = zeros(nstep - 1, num_dv + num_aux);
    Obj2 = zeros(nstep - 1, num_dv + num_aux);

    for k = 1:nstep - 1
        %% Ŀ�꺯��
        Obj1(k, 3 * nstep + k:3 * nstep + k + 1) = [-1, 1];
        Obj2(k, 4 * nstep + k:4 * nstep + k + 1) = [-1, 1];
        %% ��ɢ�����˶�ѧ����
        Apdyn(k, 2 * k - 1:2 * k + 1) = [-1, 0, 1];
        Aqdyn(k, 2 * k:2 * k + 2) = [-1, 0, 1];
        Athetadyn(k, k:k + 1) = [-1, 1];
        %% ��ɢ�Ĵ���״̬����
        index1 = [3 * nstep + k:3 * nstep + k + 1, num_dv];
        index2 = [4 * nstep + k:4 * nstep + k + 1, num_dv];
        Av1(k, index1) = [-1, 1, -vehicle_kinematics_.vehicle_a_max / (nstep - 1)];
        Av2(k, index1) = [1, -1, -vehicle_kinematics_.vehicle_a_max / (nstep - 1)];
        Aphi1(k, index2) = [-1, 1, -vehicle_kinematics_.vehicle_omega_max / (nstep - 1)];
        Aphi2(k, index2) = [1, -1, -vehicle_kinematics_.vehicle_omega_max / (nstep - 1)];
    end

    k = nstep;

    %% Ŀ�꺯����һ����
    F = zeros(num_dv + num_aux, 1);
    F(num_dv) = 1; %ʹʱ����С
    F(num_dv + 1:end) = lambda * ones(num_aux, 1); %�ͷ���ʽԼ��
    f = zeros(num_dv, 1);
    f(end) = 1; %ʹʱ����С
    % Ŀ�꺯���Ķ�����
    H = 2 * (Obj1' * Obj1 + Obj2' * Obj2);
    H_x = 2 * (Obj1(:, 1:num_dv)' * Obj1(:, 1:num_dv) + Obj2(:, 1:num_dv)' * Obj2(:, 1:num_dv));

    %% ��ʽԼ�������ƹ켣����ֹ״̬x,y,theta,v,phi
    Aeq0 = zeros(10, num_dv + num_aux);
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

    %% �߽�����Լ��
    lb = zeros(num_dv + num_aux, 1);
    ub = zeros(num_dv + num_aux, 1);
    % �켣��������ķ�Χ����
    lb(1:dim:dim * nstep) = planning_scale_.xmin;
    lb(2:dim:dim * nstep) = planning_scale_.ymin;
    ub(1:dim:dim * nstep) = planning_scale_.xmax;
    ub(2:dim:dim * nstep) = planning_scale_.ymax;
    % theta�����½磨���������������Ϊ�˷�ֹ�����ⳡ���½Ƕ���2pi����������
    lb(2 * nstep + 1:3 * nstep) = -10000; %-Inf
    ub(2 * nstep + 1:3 * nstep) = 10000; %Inf
    % v�����½�
    lb(3 * nstep + 1:4 * nstep) = vehicle_kinematics_.vehicle_v_min;
    ub(3 * nstep + 1:4 * nstep) = vehicle_kinematics_.vehicle_v_max;
    % phi�����½�
    lb(4 * nstep + 1:5 * nstep) = vehicle_kinematics_.vehicle_phi_min;
    ub(4 * nstep + 1:5 * nstep) = vehicle_kinematics_.vehicle_phi_max;
    % ��ʻʱ������½�
    lb(5 * nstep + 1) = 0;
    ub(5 * nstep + 1) = 1000;
    % ��ʽ�ͷ�
    lb(num_dv + 1:end) = 0; %lb(num_dv+1:end)=-inf;
    ub(num_dv + 1:end) = inf;
    % ������Լ��
    Tr = zeros(num_dv, num_dv + num_aux);
    Tr(1:num_dv, 1:num_dv) = eye(num_dv);

    % ����x0���˶�ѧԼ���������
    F_x0 = [Apdyn * x0(1:2 * nstep) - Ts * vel(1:nstep - 1) .* cos(theta(1:nstep - 1)); Aqdyn * x0(1:2 * nstep) - Ts * vel(1:nstep - 1) .* sin(theta(1:nstep - 1)); Athetadyn * theta(1:nstep) - Ts / Lm * vel(1:nstep - 1) .* tan(phi(1:nstep - 1))];

    % ���˶�ѧԼ��F(x)=0�������Ի���һ��̩��չ�������õ�delta_Jac��delta_b
    delta_Jac = ComputeJac(x0, Lm);
    delta_b = -F_x0 + delta_Jac * x0;

    % ��Ŀ�꺯��ֵ������ԭʼĿ��ͳͷ��
    J_x0 = 1/2 * x0' * H_x * x0 + f' * x0 + lambda * norm(F_x0, 1);

    x_star = x0; % x_star�ǵ�ǰ��õĹ켣
    z0 = [x0; abs(F_x0)]; % z_trajectory = [x0;F_x0];  ע�⸨���������ڵ���0��������
    z = z0;

    cost_counter = 1; %ͳ���Ѿ������˶��ٴ���ѭ��
    no_improve_counter = 0; %ͳ���Ѿ����ٴ�û�иĽ�ԭʼĿ�꺯��ֵ��
    cost(cost_counter) = 1/2 * x0' * H_x * x0 + f' * x0;
    violation(cost_counter) = norm(F_x0, 1);

    cost_violation = []; %�������Լ����Υ�����

    eq_flag = 0;

    %% ��ʼ����
    for k = 1:maxiter
        radius = radius0; % %ÿ����ѭ���������ϰ���û��ʱ��ֻ��������뾶���ˣ�������������
        %% ����Լ��
        A = zeros(num_collision_max, num_dv + num_aux);
        b = zeros(num_collision_max, 1);
        %% ����Լ��
        counter_collision = 1; %ͳ�Ʊ���Լ��������
        % ����ÿһ��ʱ�̽��е���
        for i = 1:nstep
            indexi = (i - 1) * dim + 1:i * dim;
            xnr = path_k(indexi); % xnr��������
            % Ϊxnr����͹���м�
            if collision_choice == 1
                [tempA, tempb] = Find_Box_for_all_obj(xnr);
            elseif collision_choice == 2
                [tempA, tempb, ~] = Find_CFS_for_all_obj(xnr, obj);
            end

            num_tempA = length(tempb);
            A(counter_collision:counter_collision - 1 + num_tempA, 2 * (i - 1) + 1:2 * i) = tempA;

            if collision_choice == 1
                b(counter_collision:counter_collision - 1 + num_tempA) = tempb;
            elseif collision_choice == 2
                b(counter_collision:counter_collision - 1 + num_tempA) = tempb - o_margin;
            end

            counter_collision = counter_collision + num_tempA;
            % ��������Բ��xir��͹���м�Լ����������ת�������߱���xr��xnr������Լ��
        end

        num_collision = counter_collision - 1;
        num_constraint = num_collision + 4 * (nstep - 1) + 2 * (5 * nstep - 3) + 2 * num_dv;
        Aineq = zeros(num_constraint, num_dv + num_aux);
        bineq = zeros(num_constraint, 1);

        %% ��ѭ����CFS��ѭ������ѭ������Թ̶���͹���м������Ż���ѭ��
        Aineq(1:num_collision, :) = A(1:num_collision, :);
        Aineq(num_collision + 1:num_collision + nstep - 1, :) = Av1;
        Aineq(num_collision + nstep:num_collision + 2 * (nstep - 1), :) = Av2;
        Aineq(num_collision + 2 * (nstep - 1) + 1:num_collision + 3 * (nstep - 1), :) = Aphi1;
        Aineq(num_collision + 3 * (nstep - 1) + 1:num_collision + 4 * (nstep - 1), :) = Aphi2;
        Aineq(num_collision + 4 * nstep - 3:num_collision + 4 * nstep - 4 + num_aux, num_dv + 1:num_dv + num_aux) = -eye(num_aux);
        Aineq(num_collision + 4 * nstep - 3 + num_aux:num_collision + 4 * nstep - 4 + 2 * num_aux, num_dv + 1:num_dv + num_aux) = -eye(num_aux);
        Aineq(num_collision + 4 * nstep - 4 + 2 * num_aux + 1:num_collision + 4 * nstep - 4 + 2 * num_aux + num_dv, :) = Tr;
        Aineq(num_collision + 4 * nstep - 4 + 2 * num_aux + num_dv + 1:num_collision + 4 * nstep - 4 + 2 * num_aux + 2 * num_dv, :) = -Tr;

        bineq(1:num_collision) = b(1:num_collision);

        z_last = z0; % ������һ�εĽ�

        for inner_index = 1:inner_maxiter
            Aineq(num_collision + 4 * nstep - 3:num_collision + 4 * nstep - 4 + num_aux, 1:num_dv) = delta_Jac;
            Aineq(num_collision + 4 * nstep - 4 + num_aux + 1:num_collision + 4 * nstep - 4 + 2 * num_aux, 1:num_dv) = -delta_Jac;

            bineq(num_collision + 4 * nstep - 3:num_collision + 4 * nstep - 4 + num_aux) = delta_b;
            bineq(num_collision + 4 * nstep - 4 + num_aux + 1:num_collision + 4 * nstep - 4 + 2 * num_aux) = -delta_b; %-delta_b
            bineq(num_collision + 4 * nstep - 4 + 2 * num_aux + 1:num_collision + 4 * nstep - 4 + 2 * num_aux + num_dv) = x0 + radius; %x0+radius;
            bineq(num_collision + 4 * nstep - 4 + 2 * num_aux + num_dv + 1:num_collision + 4 * nstep - 4 + 2 * num_aux + 2 * num_dv) = -x0 + radius; %-x0+radius;

            cost_counter = cost_counter + 1;

            %% ��δ����ǰ��ͳ��Լ��Υ�����
            ceq1 = Aeq0 * z0 - beq0;
            theta = z0(2 * nstep + 1:3 * nstep);
            vel = z0(3 * nstep + 1:4 * nstep);
            phi = z0(4 * nstep + 1:5 * nstep);
            Ts = z0(5 * nstep + 1) / (nstep - 1);
            ceq2 = [Apdyn * z0(1:2 * nstep) - Ts * vel(1:nstep - 1) .* cos(theta(1:nstep - 1)); Aqdyn * z0(1:2 * nstep) - Ts * vel(1:nstep - 1) .* sin(theta(1:nstep - 1)); Athetadyn * theta(1:nstep) - Ts / Lm * vel(1:nstep - 1) .* tan(phi(1:nstep - 1))];
            ceq = [ceq1; ceq2];

            %% ����ʽ
            cineq1 = Aineq(1:num_dv, :) * z0 - bineq(1:num_dv);
            cineq2 = lb(1:num_dv) - z0(1:num_dv);
            cineq3 = z0(1:num_dv) - ub(1:num_dv);
            cineq = [cineq1; cineq2; cineq3];

            %% ����Լ��Υ����
            vv = [norm(max(cineq, 0), 2), norm(ceq1, 2), norm(ceq2, 2)];
            cost_violation = [cost_violation; vv];

            if norm(ceq2, 2) < 0.001 %���Լ��������ֱ���˳�ѭ��  1e-2
                x = z0(1:num_dv);
                isFeasible = 1;
                eq_flag = 1;
                break;
            end

            %% ���ǰ������Լ��Υ���ı仯��С��һ��ֵҲ�˳�
            if k > 1

                if norm(cost_violation(k, 3) - cost_violation(k - 1, 3)) < 0.001
                    break;
                end

            end

            %% ���ײ��Ż�����
            options = cplexoptimset;
            options.Display = 'off';
            [z, ~, exitflag, ~] = cplexqp(H, F, Aineq, bineq, Aeq0, beq0, lb, ub, z0, options);

            if (exitflag == 0) || (sum(isnan(z)) > 0) || (isempty(z) > 0)
                isFeasible = 0;
                x = z0(1:num_dv);
                trajectory.x = z_last(1:2:dim * nstep);
                trajectory.y = z_last(2:2:dim * nstep);
                trajectory.theta = z_last(2 * nstep + 1:3 * nstep);
                trajectory.v = z_last(3 * nstep + 1:4 * nstep);
                trajectory.phi = z_last(4 * nstep + 1:5 * nstep);
                trajectory.tf = z_last(5 * nstep + 1);
                break;
            else
                z0 = z;
                z_last = z;
            end

            aux = z(num_dv + 1:end);
            x = z(1:num_dv);

            %% ����delta_J��delta_L
            theta = x(2 * nstep + 1:3 * nstep);
            vel = x(3 * nstep + 1:4 * nstep);
            phi = x(4 * nstep + 1:5 * nstep);
            Ts = x(5 * nstep + 1) / (nstep - 1);
            F_x = [Apdyn * x(1:2 * nstep) - Ts * vel(1:nstep - 1) .* cos(theta(1:nstep - 1)); Aqdyn * x(1:2 * nstep) - Ts * vel(1:nstep - 1) .* sin(theta(1:nstep - 1)); Athetadyn * theta(1:nstep) - Ts / Lm * vel(1:nstep - 1) .* tan(phi(1:nstep - 1))];
            J_x = 1/2 * x' * H_x * x + f' * x + lambda * norm(F_x, 1);
            delta_J = J_x0 - J_x;
            L_x = 1/2 * x' * H_x * x + f' * x + lambda * norm(aux, 1);
            delta_L = J_x0 - L_x;

            if norm(F_x, 1) < 1e-5 % ������䣬���Լ��������ֱ���˳�ѭ��  1e-2
                isFeasible = 1;
                eq_flag = 1;
                break;
            end

            %% �������ѭ���ĵ�һ�ε�������ֱ�ӽ���
            if ((inner_index == 1) && (delta_L > threshold))
                x0 = x;
                F_x0 = F_x;
                delta_Jac = ComputeJac(x0, Lm);
                delta_b = -F_x0 + delta_Jac * x0;
                J_x0 = J_x;
                z0 = [x0; abs(F_x0)]; %z0 = [x0;abs(F_x0)];
                cost(cost_counter) = 1/2 * x0' * H_x * x0 + f' * x0;
                violation(cost_counter) = norm(F_x0, 1);
                radius = radius / ratio; % ����ʱ���д�Χ���������ʹ�ô��������뾶���ֲ��Ż�ʹ��С������뾶
                continue;
            end

            if delta_J < -1e-3 % ˵��û���𵽸Ľ��켣�����ã�������ϴ�ʱһ���������������

                if radius <= radius_low % %ע�⣺��Ҫ������һ���˳�����ģ��Ľ���С����
                    break;
                end

                if violation(cost_counter - 1) < 0.001
                    no_improve_counter = no_improve_counter + 1;

                    if no_improve_counter >= inner_counter
                        break;
                    end

                end

                radius = max(radius / alpha, radius_low);
                %% ����ֱ������
                delta_x = (x - x0);

                % ����ı����ܽӽ������˳���ѭ��
                if norm(delta_x) > 0.001 * nstep * (dim)
                    merit_function_x0 = 1/2 * x0' * H_x * x0 +f' * x0 + mup * norm(F_x0, 1);
                    D_merit_function_x0 = (x0' * H_x + f' + mup * sign(F_x0)' * delta_Jac) * delta_x;

                    for line_search = 1:15
                        temp_x = x0 + step_size * delta_x;
                        linear_error = norm(temp_x - x0, inf);
                        F_tempx = [Apdyn * temp_x(1:2 * nstep) - (temp_x(5 * nstep + 1) / (nstep - 1)) * temp_x(3 * nstep + 1:4 * nstep - 1) .* cos(temp_x(2 * nstep + 1:3 * nstep - 1)); Aqdyn * temp_x(1:2 * nstep) - (temp_x(5 * nstep + 1) / (nstep - 1)) * temp_x(3 * nstep + 1:4 * nstep - 1) .* sin(temp_x(2 * nstep + 1:3 * nstep - 1)); Athetadyn * temp_x(2 * nstep + 1:3 * nstep) - (temp_x(5 * nstep + 1) / (nstep - 1)) / Lm * temp_x(2 * nstep + 1:3 * nstep - 1) .* tan(temp_x(2 * nstep + 1:3 * nstep - 1))];
                        merit_function_tempx = 1/2 * temp_x' * H_x * temp_x + f' * temp_x + mup * norm(F_tempx, 1);
                        thershold = merit_function_x0 + alpha1 * step_size * D_merit_function_x0;

                        if merit_function_tempx <= thershold
                            x0 = temp_x;
                            F_x0 = F_tempx;
                            break;
                        else
                            step_size = step_size * beta1;
                        end

                    end

                    radius = min(radius, linear_error);
                else
                    x0 = x;
                    break;
                end

            elseif abs(delta_J) < threshold % delta_J<threshold
                break;
            elseif delta_J > 1
                x0 = x;
                F_x0 = F_x;
                delta_Jac = ComputeJac(x0, Lm);
                delta_b = -F_x0 + delta_Jac * x0;
                J_x0 = J_x;
                z0 = [x0; abs(F_x0)]; %z0 = [x0;F_x0];

                % �ж����Ի����Ƴ̶ȣ��Ե���������뾶
                if norm(aux, 1) > threshold_linear_error
                    rho_k = norm(aux, 1) / norm(F_x, 1);
                else
                    rho_k = threshold_linear_error / norm(F_x, 1);
                end

                if rho_k < rho1 %���Ի����ϴ���С������
                    radius = max(radius / alpha, radius_low);
                else
                    threshold_linear_error = 0.1 * threshold_linear_error;

                    if rho_k >= rho2 % ���Ի�����С�����ʵ�����������
                        radius = min(beta * radius, radius_up);
                    end

                end

            end

            cost(cost_counter) = 1/2 * x0' * H_x * x0 + f' * x0;
            violation(cost_counter) = norm(F_x0, 1);

            % ���Լ��Υ���̶Ƚ�С�ˣ���Ϊ��ʱ����������׶��ˣ���ֱ�ӽ�������뾶����Ϊ��С��ֵ
            if (norm(aux, 1) < 1e-4) && ((violation(cost_counter) < 0.1) || ((violation(cost_counter) < 0.5) && (abs(violation(cost_counter) - violation(cost_counter - 1) < 0.1))))
                radius = min(radius, 0.01);
            end

        end

        no_improve_counter = 0;
        iter(k) = inner_index;

        if norm(F_x0, 2) < 0.01 %1e-2 %1e-4
            eq_flag = 1;
        end

        if eq_flag == 1 % ������䣬���Լ��������ֱ���˳�ѭ��
            break;
        end

    end

    %% �ڽ�������ͳ��һ�μ���Υ��Լ�������
    vv = [norm(max(cineq, 0), 2), norm(ceq1, 2), norm(F_x0, 2)];
    cost_violation = [cost_violation; vv];

    %% �жϵ���maxiter���ҵ��Ĺ켣�Ƿ������˶�ѧԼ���ͱ���Լ�����Ƿ������ҵ����н⣩
    if isFeasible

        if sum(lb - z) <= 0 && sum(z - ub) <= 0 && sum(Aineq * z - bineq) <= 0 && sum(abs(Aeq0 * z - beq0)) <= 0.1
            isFeasible = 1;
        else
            isFeasible = 0;
        end

    end

    %% ����������cplexqp�����ܶ����δ�ҵ����н⣬�����fmincon���������ͼ���
    if isFeasible == 0 || isempty(z)
        x = [];
%         fun = @(x)1/2 * x' * H_x * x + f' * x;
%         nonlcon = @(x)kinematiccon(x, nstep, Apdyn, Aqdyn, Athetadyn, Lm);
%         options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp');
%         [x, ~, exitflag, ~] = fmincon(fun, x0, Aineq(1:num_collision + 4 * (nstep - 1), 1:num_dv), bineq(1:num_collision + 4 * (nstep - 1)), Aeq0(:, 1:num_dv), beq0, lb(1:num_dv), ub(1:num_dv), nonlcon, options);
% 
%         if isempty(x) || exitflag == -2
%             isFeasible = 0;
%             x = [refpath_vec; theta0; v0; phi0; tf0];
%         end

    else
        x = z(1:num_dv);
    end

    %% �ٴζ���õĽ����Լ�����
    if isFeasible == 1

        if norm(kinematiccon(x, nstep, Apdyn, Aqdyn, Athetadyn, Lm)) < 1e-3 && sum(lb(1:num_dv) - x) <= 0 ...
                && sum(x - ub(1:num_dv)) <= 0 && sum(Aineq(1:num_collision + 4 * (nstep - 1), 1:num_dv) * x - bineq(1:num_collision + 4 * (nstep - 1))) <= 0 ...
                && sum(abs(Aeq0(:, 1:num_dv) * x - beq0)) <= 0.1
            isFeasible = 1;
        else
            isFeasible = 0;
        end

    end
    
    if isFeasible == 1
        trajectory.x = x(1:2:dim * nstep);
        trajectory.y = x(2:2:dim * nstep);
        trajectory.theta = x(2 * nstep + 1:3 * nstep);
        trajectory.v = x(3 * nstep + 1:4 * nstep);
        trajectory.phi = x(4 * nstep + 1:5 * nstep);
        trajectory.tf = x(5 * nstep + 1);
    else
        trajectory = 0;
    end

end

function [c, ceq] = kinematiccon(x, nstep, Apdyn, Aqdyn, Athetadyn, Lm)
    c = [];
    theta = x(2 * nstep + 1:3 * nstep);
    vel = x(3 * nstep + 1:4 * nstep);
    phi = x(4 * nstep + 1:5 * nstep);
    Ts = x(5 * nstep + 1) / (nstep - 1);
    ceq = [Apdyn * x(1:2 * nstep) - Ts * vel(1:nstep - 1) .* cos(theta(1:nstep - 1)); Aqdyn * x(1:2 * nstep) - Ts * vel(1:nstep - 1) .* sin(theta(1:nstep - 1)); Athetadyn * theta(1:nstep) - Ts / Lm * vel(1:nstep - 1) .* tan(phi(1:nstep - 1))];
end

function Jac = ComputeJac(x, Lm)
    num_dv = length(x);
    nstep = (num_dv - 1) / 5;
    delta_t = x(end) / (nstep - 1);
    Jac = zeros(3 * nstep - 3, num_dv);

    for kkk = 1:nstep - 1
        index1 = [2 * kkk - 1, 2 * kkk + 1, 2 * nstep + kkk, 3 * nstep + kkk, num_dv];
        Jac(kkk, index1) = [-1, 1, delta_t * x(3 * nstep + kkk) * sin(x(2 * nstep + kkk)), -delta_t * cos(x(2 * nstep + kkk)), -x(3 * nstep + kkk) * cos(x(2 * nstep + kkk)) / (nstep - 1)];
        index2 = [2 * kkk, 2 * kkk + 2, 2 * nstep + kkk, 3 * nstep + kkk, num_dv];
        Jac(nstep - 1 + kkk, index2) = [-1, 1, -delta_t * x(3 * nstep + kkk) * cos(x(2 * nstep + kkk)), -delta_t * sin(x(2 * nstep + kkk)), -x(3 * nstep + kkk) * sin(x(2 * nstep + kkk)) / (nstep - 1)];
        index3 = [nstep * 2 + kkk, nstep * 2 + kkk + 1, 3 * nstep + kkk, 4 * nstep + kkk, num_dv];
        Jac(2 * nstep - 2 + kkk, index3) = [-1, 1, -delta_t * tan(x(4 * nstep + kkk)) / Lm, -delta_t * x(3 * nstep + kkk) / (cos(x(4 * nstep + kkk))^2 * Lm), -x(3 * nstep + kkk) * tan(x(4 * nstep + kkk)) / ((nstep - 1) * Lm)];
    end

end

%% ��һ�ִ�����ײԼ���ķ�����Box
function [A, b] = Find_Box_for_all_obj(xr)
    % xr�Ĵ�С2*1
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

%% �ڶ��ִ�����ײԼ���ķ�����CFS
function [A, b, d] = Find_CFS_for_all_obj(xr, obstacle)
    %% ����ϰ�������obj��Ϊ��ǰ�ο���xrѰ��͹���м�CFS��F(xr)
    % xr�Ĵ�С2*1��obj�Ĵ�С2*4��ÿһ����һ����������꣩
    %% ����ȷ������phi����Ϊʵ���е��ϰ��ﶼ��͹�ģ����phiȡΪ�����еĹ�ʽ(23)
    % 1. ��Ҫע����ǣ���ʽ��23����ʾ����phi��͹���������ҹ⻬����˴��ݶȼ���Ϊ���㼯��ֻ����һ��Ԫ�ء����ݶ�
    % 2. ����������ҪѰ���ϰ���߽��Ͼ���xr����ĵ㣺���ο��Ǹ������ڶ���
    ncorner = size(obstacle, 2); %�ϰ��ﶥ�����
    nobj = size(obstacle, 1) / 2;
    d = inf * ones(nobj, 1); % xr���ϰ������С�����ʼֵ��Ϊ�����
    % �������е��ϰ���õ���͹���м�(aTx<=b)������pre_A��pre_b��
    pre_A = zeros(nobj, 2);
    pre_b = zeros(nobj, 1);
    counter = 0;
    index_true = ones(nobj, 1); % index_true(j)=0��ʾ�ų��˵�j��ֱ��
    %% ȷ���˺���phi֮��F(xr)Ϊ��phi(xr) + delta_phi(xr)*(x-xr)>=0
    for j = 1:nobj
        counter = counter + 1;
        obj = obstacle(2 * j - 1:2 * j, :);

        for i = 1:ncorner
            corner1 = obj(:, i);
            corner2 = obj(:, mod(i, ncorner) + 1);
            % xr,corner1�Լ�corner2���㹹�������Σ������ߵĳ���
            dist_r1 = norm(xr - corner1);
            dist_r2 = norm(xr - corner2);
            dist_12 = norm(corner1 - corner2);
            % ����r12Ϊ�۽ǣ����ʱxr����corner1����
            if (dist_r1^2 + dist_12^2 - dist_r2^2) < -1e-4 %���Ҷ���
                temp_d = dist_r1;
                temp_A = xr' - corner1';
                temp_b = temp_A * corner1;
            elseif (dist_r2^2 + dist_12^2 - dist_r1^2) < -1e-4 % ����r21Ϊ�۽ǣ����ʱxr����corner2����
                temp_d = dist_r2;
                temp_A = xr' - corner2';
                temp_b = temp_A * corner2;
            else % ����r12�Լ���r21��Ϊ��ǣ���xr����corner1��corner2���ɵ�ֱ�߶εĴ������
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

        %     %% ��xr����Ķ���ĶԽǵ㣬��xrӦ�÷־�ֱ��Ax=b������
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

    %% �����Ƿ�pre_A��pre_b���Ƿ�������Լ��
    %% �����棬ÿһ���ϰ��ﶼ��Ӧ����һ��ֱ�߷ָ�xr���ϰ��ﱾ������ų�����ֱ�ߣ�ʣ�µ�ֱ����Ȼ���Էָ�����ϰ����xr,������ֱ��ȷʵ���Դ�Լ�����ų�
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
