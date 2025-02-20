/*
#  This is the template for cpp Source Codes of different trajectory
#  planner in unstructured environments.The randomly generated obstacles are
#  oriented in different directions.
*/
#include <iostream>
#include <math.h>
#include <vector>
#include <chrono>
#include <random>
#include "vec2d.h"

#include <opencv2/opencv.hpp>
#include "mathstruct.h"
#include "TransformP2T.h"
#include "Visualize.h"
#include "state_lattice_planner.h"
using namespace cv;

/* run this program using the console pauser or add your own getch, system("pause") or input loop */
using namespace std;
struct Vehicle_geometrics_ vehicle_geometrics_;
struct Vehicle_kinematics_ vehicle_kinematics_;
struct Hybrid_astar_ hybrid_astar_;
struct Vehicle_TPBV_ vehicle_TPBV_;
struct Planning_scale_ planning_scale_;

int num_nodes_s = 60;
double margin_obs_ = 0.5;
int Nobs = 4;
// for data from python
int loaddata();
vector<double> InputData_To_Vector(string filename);
vector<vector<math::Vec2d> > obstacles_ ;

vector < vector<math::Vec2d>> GenerateObstacles() {
    vector<vector<math::Vec2d>> obstacle_cell;
    vector<math::Vec2d> temp_obj;
    math::Vec2d a(0, 5);
    math::Vec2d b(24, 5);
    math::Vec2d c(24, 60);
    math::Vec2d d(0, 60);
    temp_obj.push_back(a);
    temp_obj.push_back(b);
    temp_obj.push_back(c);
    temp_obj.push_back(d);
    obstacle_cell.push_back(temp_obj);
    vector<math::Vec2d> temp_obj_2;
    math::Vec2d a_2(36, 5);
    math::Vec2d b_2(60, 5);
    math::Vec2d c_2(60, 60);
    math::Vec2d d_2(36, 60);
    temp_obj_2.push_back(a_2);
    temp_obj_2.push_back(b_2);
    temp_obj_2.push_back(c_2);
    temp_obj_2.push_back(d_2);
    obstacle_cell.push_back(temp_obj_2);
    vector<math::Vec2d> temp_obj_3;
    math::Vec2d a_3(29, 0);
    math::Vec2d b_3(31, 0);
    math::Vec2d c_3(31, 27.5);
    math::Vec2d d_3(29, 27.5);
    temp_obj_3.push_back(a_3);
    temp_obj_3.push_back(b_3);
    temp_obj_3.push_back(c_3);
    temp_obj_3.push_back(d_3);
    obstacle_cell.push_back(temp_obj_3);
    vector<math::Vec2d> temp_obj_4;
    math::Vec2d a_4(29, 32.5);
    math::Vec2d b_4(31, 32.5);
    math::Vec2d c_4(31, 60);
    math::Vec2d d_4(29, 60);
    temp_obj_4.push_back(a_4);
    temp_obj_4.push_back(b_4);
    temp_obj_4.push_back(c_4);
    temp_obj_4.push_back(d_4);
    obstacle_cell.push_back(temp_obj_4);

    return obstacle_cell;
}

int ImprovedStateLatticeTest()
{
    planning_scale_.xmax = 60;
    planning_scale_.ymax = 60;
    vehicle_TPBV_.x0 = 4;
    vehicle_TPBV_.y0 = 2;
    vehicle_TPBV_.xtf = 56;
    vehicle_TPBV_.ytf = 2;
    vehicle_TPBV_.theta0 = 0;
    vehicle_TPBV_.thetatf = 0;
    //Nobs = 40;
    auto now = chrono::high_resolution_clock::now();
    srand(now.time_since_epoch().count());
    // obstacles_= GenerateStaticObstacles_unstructured();
    obstacles_ = GenerateObstacles();
    int transmethod_flag = 1;
    auto start_time = chrono::high_resolution_clock::now();

    PlanningResult result = ImprovedStateLatticePlan(1, "./look_up_table_235033.txt", "./insert_points.txt");
    auto end_time = chrono::high_resolution_clock::now();
    std::cout << "ImprovedStateLatticePlan time consumed: " << 
        chrono::duration_cast<chrono::milliseconds>(end_time - start_time).count() << 
        " ms" <<
        std::endl;
    if (result.is_complete == 0)
    {
        cout<< "Planning failed. Can not reach the destination." << endl;
        return 1;
    }
    struct Trajectory trajectory = TransformPathToTrajectory(result.x, result.y, result.theta, result.path_length, transmethod_flag);
    // cout << "trajectory test:" << trajectory.x[2] << endl;
    // cout << "trajectory test:" << trajectory.y[2] << endl;

    VisualizeDynamicResults(trajectory);

    return 0;
}

int ImprovedStateLatticeTime()
{
    planning_scale_.xmax = 60;
    planning_scale_.ymax = 60;
    vehicle_TPBV_.x0 = 4;
    vehicle_TPBV_.y0 = 4;
    vehicle_TPBV_.xtf = 54;
    vehicle_TPBV_.ytf = 54;
    vehicle_TPBV_.theta0 = 0;
    vehicle_TPBV_.thetatf = M_PI;
    for (int i = 0; i < 41; i++) {
        Nobs = i;
        cout << Nobs << endl;
        auto now = chrono::high_resolution_clock::now();
        srand(now.time_since_epoch().count());
        obstacles_ = GenerateStaticObstacles_unstructured();
        int transmethod_flag = 1;
        auto start_time = chrono::high_resolution_clock::now();

        PlanningResult result = ImprovedStateLatticePlan(1, "./look_up_table_235033.txt", "./insert_points.txt");
        auto end_time = chrono::high_resolution_clock::now();
        std::cout << "ImprovedStateLatticePlan time consumed: " <<
            chrono::duration_cast<chrono::milliseconds>(end_time - start_time).count() <<
            " ms" <<
            std::endl;
    }
    return 0;
}

int main_bk(int argc, char** argv) {
    //Mat test = imread("test.jpg"); //载入图像到test
    //imshow("test", test);
    //waitKey(0);
    //printf("%f\n", vehicle_kinematics_.min_turning_radius);
    //printf("%f\n", vehicle_TPBV_.phitf);
    
    obstacles_ = GenerateStaticObstacles_unstructured();
    obstacles_ = GenerateStaticObstacles_unstructured();


    cout << "load data test" << endl;
    vector<double> x = InputData_To_Vector("./x.txt");
    vector<double> y = InputData_To_Vector("./y.txt");
    vector<double> theta = InputData_To_Vector("./theta.txt");
    //cout << "vectorload:" << x[1] << endl;
    //cout << "vectorload:" << y[1] << endl;
    //cout << "vectorload:" << theta[1] << endl;

    int transmethod_flag = 1;
    double path_length = 40.16013599;
     
    struct Trajectory trajectory = TransformPathToTrajectory(x,y,theta,path_length,transmethod_flag);
    cout << "trajectory test:" << trajectory.x[2] << endl;
    cout << "trajectory test:" << trajectory.y[2] << endl;
    //Point2d
    double varx = 1.2;
    Point test(varx, varx);
    VisualizeStaticResults(trajectory);
    VisualizeDynamicResults(trajectory);
    cout << "Point test:" << test.x << endl;
    return 0;
}


int main(int argc, char** argv) 
{
    ImprovedStateLatticeTest();
}