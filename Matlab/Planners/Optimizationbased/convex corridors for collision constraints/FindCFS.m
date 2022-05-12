function [A, b, d] = FindCFS(xr, obstacle)
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