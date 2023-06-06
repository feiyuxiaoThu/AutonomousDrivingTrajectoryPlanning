function obstacle_cell = GenerateDynamicObstacles_unstructured()
global st_graph_search_  
Nobs_dyn = 5;
dynamic_obs = cell(2,5); % �ṹ�壬��һ�д洢��̬�ϰ�������λ�ã��ڶ��д洢��̬�ϰ�����յ�λ��
% ��1���ϰ�������
dynamic_obs{1,1}.x=[10,15,15,10]; dynamic_obs{1,1}.y=[10,10,15,15];
dynamic_obs{2,1}.x=[45,50,50,45]; dynamic_obs{2,1}.y=[10,10,15,15];
% ��2���ϰ�������
dynamic_obs{1,2}.x=[45,50,50,45]; dynamic_obs{1,2}.y=[10,10,15,15];
dynamic_obs{2,2}.x=[45,50,50,45]; dynamic_obs{2,2}.y=[45,45,50,50];
% ��3���ϰ�������
dynamic_obs{1,3}.x=[45,50,50,45]; dynamic_obs{1,3}.y=[45,45,50,50];
dynamic_obs{2,3}.x=[10,15,15,10]; dynamic_obs{2,3}.y=[45,45,50,50];
% ��4���ϰ�������
dynamic_obs{1,4}.x=[10,15,15,10]; dynamic_obs{1,4}.y=[45,45,50,50];
dynamic_obs{2,4}.x=[10,15,15,10]; dynamic_obs{2,4}.y=[10,10,15,15];
% ��5���ϰ�������
dynamic_obs{1,5}.x=[17,19,25,23]; dynamic_obs{1,5}.y=[19,17,23,25];
dynamic_obs{2,5}.x=[34,36,42,40]; dynamic_obs{2,5}.y=[36,34,40,42];

obstacle_cell = cell(st_graph_search_.num_nodes_t, Nobs_dyn);
for ii = 1 : Nobs_dyn
    dx = dynamic_obs{end,ii}.x(1) - dynamic_obs{1,ii}.x(1);
    dy = dynamic_obs{end,ii}.y(1) - dynamic_obs{1,ii}.y(1);
    for jj = 1 : st_graph_search_.num_nodes_t
        temp.x = dynamic_obs{1,ii}.x + dx / st_graph_search_.num_nodes_t * (jj - 1);
        temp.y = dynamic_obs{1,ii}.y + dy / st_graph_search_.num_nodes_t * (jj - 1);
        obstacle_cell{jj, ii} = temp;
    end
end
end