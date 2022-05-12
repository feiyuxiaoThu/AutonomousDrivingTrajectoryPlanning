#include "state_lattice.h"
#include "mathstruct.h"
#include <fstream>
#include <iostream>
#include "json.hh"
#include "actions.h"

using json = nlohmann::json;
using namespace std;

int action2cost(int direction, vector<int> action)
{
    int delta_x = abs(action[0]);
    int delta_y = abs(action[1]);
    int x = max(delta_x, delta_y);
    int y = min(delta_x, delta_y);
    if (direction % 2 == 0) {
        if (x == 9) {
            return 10.734;
        }
        else if (x == 11) {
            return 13.263;
        }
        else if (x == 12) {
            return 15.109;
        }
        else if (x == 7) {
            if (y == 3) {
                return 11.498;
            }
            else {
                return 16.616;
            }
        }
        else {
            return 1;
        }
    }
    else {
        if (y == 6) {
            return 9.992;
        }
        else if (y == 3) {
            return 11.498;
        }
        else if (y == 0) {
            return 16.603;
        }
        else if (y == 7) {
            if (x == 9) {
                return 12.374;
            }
            else {
                return 13.728;
            }
        }
        else {
            return 1.414;
        }
    }
    
}

StateLatticeGraph::StateLatticeGraph(int x_len, int y_len, const ActionSet & ac_set) noexcept
{
    this->direction_num = 8;
    this->x_length = x_len;
    this->y_length = y_len;
    this->node_num = x_len * y_len * this->direction_num;
    this->action_set = ac_set;
    // construct graph.
    this->build_graph();
}


std::pair<Position, int> StateLatticeGraph::index2position(NodeIndex index) const
{  
    // actually this is the way to calculate the index of a multi-dimensional array.
    int x = index / (this->y_length * this->direction_num);
    int y = (index - x * this->y_length * this->direction_num) / this->direction_num;
    int direction = index - x * this->y_length * this->direction_num - y * this->direction_num;
    return std::make_pair(Position(x, y), direction);
 }

NodeIndex StateLatticeGraph::position2index(Position position, int direction) const 
{
    // actually this is the way to calculate the index of a multi-dimensional array.
    int x = position.x();
    int y = position.y();
    return (NodeIndex)(x * this->y_length * this->direction_num + y * this->direction_num + direction);
}

void StateLatticeGraph::build_graph() 
{
    // add nodes
    for(NodeIndex index = 0; index < this->node_num ; index++ )
    {
        auto result = this->index2position(index);

        this->nodes.push_back(LatticeNode(result.first, result.second));

    }

    // add edges
    for(NodeIndex index = 0; index < this->node_num ; index++ )
    {
        auto result = this->index2position(index);
        auto current_pos = result.first;
        auto direction = result.second;
        // get all possible action of current_pos & current_direction.
        auto direction_actions = this->action_set.get_actions(current_pos, direction, this->x_length, this->y_length);
        vector<LatticeEdge> action_edges;
        for (auto iter = direction_actions.begin(); iter < direction_actions.end(); iter++)
        {
            auto & action = *iter;
            auto next_position = Position(current_pos.x() + action[0], current_pos.y() + action[1]);
            auto next_direction = action[2];
            // get the index of the adjacent node.
            auto adj_index = this->position2index(next_position, next_direction);
            LatticeEdge edge(adj_index, action2cost(direction, action));
            action_edges.push_back(edge);
        }
        this->edges.push_back(action_edges);
    }

}

void ActionSet::load_data(string insert_points_filename)
{

    std::ifstream ip_file;
    ip_file.open(insert_points_filename);
    if (!ip_file.is_open())
    {
        cout << "Insert points file not found." << endl;
        std::exit(1);
    }


    // load the actions 
    this->actions = json::parse(action_primitives.data());

    std::stringstream buffer2;
    buffer2 << ip_file.rdbuf();
    string s2 = string(buffer2.str());
    // load the insert points data.
    this->sample_points_list = json::parse(s2.data());

}

vector<vector<int>>  ActionSet::get_actions(Position position, int direction, int x_length, int y_length)
{
    auto action_list = this->actions[std::to_string(direction)].get<std::vector<std::vector<int>> >();
    // action_clean will remove the invalid action of specific position/direction
    return this->action_clean(action_list, position, x_length, y_length);

}

pair<pair<vector<double>, vector<double> >, vector<double> > 
        ActionSet::sample_points(Position start_pos, int start_direction, Position end_pos, int end_direction) const
{
    auto delta_pos = end_pos - start_pos;
    // get all actions 
    auto action_list = this->actions[std::to_string(start_direction)].get<std::vector<std::vector<int>> >();

    auto iter  = action_list.begin();
    for(; iter < action_list.end(); iter++)
    {
        auto & action = *iter;
        if (action[0] == delta_pos.x() && action[1] == delta_pos.y() && action[2] == end_direction)
        {
            break;
        }
    }
    // find the index of the current action
    int action_index = iter - action_list.begin();
    auto xyt_result = this->sample_points_list[std::to_string(start_direction)][to_string(action_index)];
    auto x_list = xyt_result["x"].get<vector<double>>();
    auto y_list = xyt_result["y"].get<vector<double>>();
    auto theta_list = xyt_result["theta"].get<vector<double>>();

    // add the base bias to sample points 
    for (int i = 0; i < x_list.size(); i++)
    {
        x_list[i] += start_pos.x();
        y_list[i] += start_pos.y();
    }
    return make_pair(make_pair(x_list, y_list), theta_list);
}

vector<vector<int> > ActionSet::action_clean(const vector<vector<int> > &action_list, Position position, int x_len, int y_len)
{
    // in order to uderstand this function, you need to know how direction is defined.
    // You can find the defination in function theta2direction.
    // There are some constrains of actions in a specific position/direction.
    // 1. the action can not get out of graph.
    // 2. the border of a graph is (0, 0) and (x_len, y_len).

    vector<vector<int>> result_actions;
    auto iter = action_list.begin();
    for(; iter < action_list.end(); iter++)
    {
        auto action = *iter;
        // check the x axis
        if (position.x() < 12)
        {
            if (position.x() + action[0] < 0 || (position.x() + action[0] == 0 && (action[2] == 3 or action[2] == 5 or action[2]==7)))
            {
                continue;
            }
        } else if (position.x() > x_len - 13)
        {
            if (position.x() + action[0] > x_len - 1 || (position.x() + action[0] == x_len - 1 && (action[2] == 3 or action[2]== 5 or action[2] == 7)))
            {
                continue;
            }
        } 
        
        // check the y axis
        if (position.y() < 12)
        {
            if (position.y() + action[1] < 0 || (position.y() + action[1] == 0 && (action[2] == 3 or action[2] == 5 or action[2] == 7)))
            {
                continue;
            }
        }
        else if (position.y() > y_len - 13)
        {
            if (position.y() + action[1] > y_len - 1 || (position.y() + action[1] == y_len - 1 && (action[2] == 3 or action[2] == 5 or action[2] == 7)))
            {
                continue;
            }
        }
        result_actions.push_back(action);
    }
    return result_actions;
}
