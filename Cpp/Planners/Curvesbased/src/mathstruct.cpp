#include <iostream>
#include <math.h>
#include <vector>
#include "vec2d.h"
#include "mathstruct.h"
#include "TransformP2T.h"
#include <time.h>
using namespace std;

// define extern varibles


//calculate of the vehicle edge position based on the position of the rear axle center
vector<math::Vec2d> CreateVehiclePolygon(double x, double y, double theta) {
    vector<math::Vec2d> V;
    double cos_theta, sin_theta;
    cos_theta = cos(theta);
    sin_theta = sin(theta);
    double vehicle_half_width;
    vehicle_half_width = vehicle_geometrics_.vehicle_width * 0.5;
    double AX, BX, CX, DX, AY, BY, CY, DY;
    AX = x + (vehicle_geometrics_.vehicle_front_hang + vehicle_geometrics_.vehicle_wheelbase) * cos_theta - vehicle_half_width * sin_theta;
    BX = x + (vehicle_geometrics_.vehicle_front_hang + vehicle_geometrics_.vehicle_wheelbase) * cos_theta + vehicle_half_width * sin_theta;
    CX = x - vehicle_geometrics_.vehicle_rear_hang * cos_theta + vehicle_half_width * sin_theta;
    DX = x - vehicle_geometrics_.vehicle_rear_hang * cos_theta - vehicle_half_width * sin_theta;
    AY = y + (vehicle_geometrics_.vehicle_front_hang + vehicle_geometrics_.vehicle_wheelbase) * sin_theta + vehicle_half_width * cos_theta;
    BY = y + (vehicle_geometrics_.vehicle_front_hang + vehicle_geometrics_.vehicle_wheelbase) * sin_theta - vehicle_half_width * cos_theta;
    CY = y - vehicle_geometrics_.vehicle_rear_hang * sin_theta - vehicle_half_width * cos_theta;
    DY = y - vehicle_geometrics_.vehicle_rear_hang * sin_theta + vehicle_half_width * cos_theta;
    math::Vec2d A(AX, AY);
    math::Vec2d B(BX, BY);
    math::Vec2d C(CX, CY);
    math::Vec2d D(DX, DY);
    V.push_back(A);
    V.push_back(B);
    V.push_back(C);
    V.push_back(D);
    V.push_back(A);

    return V;
}

vector<math::Vec2d> CreateVehiclePolygon(math::Vec2d p1, math::Vec2d p2, double theta) {
    //p1--->p2
    //p1.d->p2.a->p2.b->p1.c->p1.d

    vector<math::Vec2d> V;
    double cos_theta, sin_theta;
    cos_theta = cos(theta);
    sin_theta = sin(theta);
    double vehicle_half_width;
    vehicle_half_width = vehicle_geometrics_.vehicle_width * 0.5;
    double AX, BX, CX, DX, AY, BY, CY, DY;
    AX = p2.x() + (vehicle_geometrics_.vehicle_front_hang + vehicle_geometrics_.vehicle_wheelbase) * cos_theta - vehicle_half_width * sin_theta;
    BX = p2.x() + (vehicle_geometrics_.vehicle_front_hang + vehicle_geometrics_.vehicle_wheelbase) * cos_theta + vehicle_half_width * sin_theta;
    CX = p1.x() - vehicle_geometrics_.vehicle_rear_hang * cos_theta + vehicle_half_width * sin_theta;
    DX = p1.x() - vehicle_geometrics_.vehicle_rear_hang * cos_theta - vehicle_half_width * sin_theta;
    AY = p2.y() + (vehicle_geometrics_.vehicle_front_hang + vehicle_geometrics_.vehicle_wheelbase) * sin_theta + vehicle_half_width * cos_theta;
    BY = p2.y() + (vehicle_geometrics_.vehicle_front_hang + vehicle_geometrics_.vehicle_wheelbase) * sin_theta - vehicle_half_width * cos_theta;
    CY = p1.y() - vehicle_geometrics_.vehicle_rear_hang * sin_theta - vehicle_half_width * cos_theta;
    DY = p1.y() - vehicle_geometrics_.vehicle_rear_hang * sin_theta + vehicle_half_width * cos_theta;
    math::Vec2d A(AX, AY);
    math::Vec2d B(BX, BY);
    math::Vec2d C(CX, CY);
    math::Vec2d D(DX, DY);
    V.push_back(A);
    V.push_back(B);
    V.push_back(C);
    V.push_back(D);
    V.push_back(A);
    return V;
}

double triArea(math::Vec2d p1, math::Vec2d p2, math::Vec2d p3) {
    // triArea is used to calculate the area of a triangle 
    double a = (p1 - p2).Length();
    double b = (p3 - p2).Length();
    double c = (p3 - p1).Length();
    double half = (a + b + c) / 2;
    double area = sqrt(half * (half - a) * (half - b) * (half - c));
    return area;
}
bool checkObj_point(math::Vec2d p, vector<math::Vec2d> obj) {
    // Determine if xr is inside the obstacle
    // The obstacle here is mainly a polygon with four vertices
    int ncorner = 4;
    double area = 0;
    double area_obj = 0;
    for (int i = 0; i < ncorner; i++) {
        area = area + triArea(p, obj[i], obj[(i + 1) % ncorner]);
    }
    for (int i = 1; i < (ncorner - 1); i++) {
        area_obj = area_obj + triArea(obj[0], obj[i], obj[(i + 1) % ncorner]);
    }

    //if the reference point is inside the obstacle, then area = polyarea
    if (abs(area - area_obj) < 0.01) {
        return 1;
    }
    return 0;
}
bool checkObj_linev(math::Vec2d p1, math::Vec2d p2, vector<math::Vec2d> obj) {
    // Determine whether the line segment formed by x1and x2 intersects the obstacle
    // The obstacle here is mainly a polygon with four vertices

    // First determine whether the vertex is inside the obstacle
    bool result = 1;
    bool result1 = checkObj_point(p1, obj);
    bool result2 = checkObj_point(p2, obj);
    if (result1 || result2) {
        return 1;
    }
    else {
        result = 0;
    }
    //If the vertices are both outside the obstacle, determine whether the two diagonals intersect the line segment
    // Direction of the line segment
    math::Vec2d v1 = p2 - p1;
    math::Vec2d c1 = obj[0];
    math::Vec2d c2 = obj[2];
    math::Vec2d v2 = c2 - c1;
    double norm_dist1 = (v2 - v1).Length();
    double norm_dist2 = (v2 + v1).Length();
    if (norm_dist1 < 1e-06 || norm_dist2 < 1e-06) {
        result = 0;
    }
    else {
        // Calculate the intersection of two lines
        double t1 = (v2.y() * (c1.x() - p1.x()) + v2.x() * (p1.y() - c1.y())) / (v1.x() * v2.y() - v2.x() * v1.y());
        double t2 = (v1.y() * (p1.x() - c1.x()) + v1.x() * (c1.y() - p1.y())) / (v2.x() * v1.y() - v1.x() * v2.y());
        if (t1 >= 0 and t1 <= 1 and t2 >= 0 and t2 <= 1) {
            return 1;
        }
    }
    c1 = obj[1];
    c2 = obj[3];
    v2 = c2 - c1;
    norm_dist1 = (v2 - v1).Length();
    norm_dist2 = (v2 + v1).Length();
    if (norm_dist1 < 1e-06 || norm_dist2 < 1e-06) {
        result = 0;
    }
    else {
        // Calculate the intersection of two lines
        double t1 = (v2.y() * (c1.x() - p1.x()) + v2.x() * (p1.y() - c1.y())) / (v1.x() * v2.y() - v2.x() * v1.y());
        double t2 = (v1.y() * (p1.x() - c1.x()) + v1.x() * (c1.y() - p1.y())) / (v2.x() * v1.y() - v1.x() * v2.y());
        if (t1 >= 0 and t1 <= 1 and t2 >= 0 and t2 <= 1) {
            return 1;
        }
    }
    //Diagonal2
    c1 = obj[1];
    c2 = obj[3];
    v2 = c2 - c1;
    norm_dist1 = (v2 - v1).Length();
    norm_dist2 = (v2 + v1).Length();
    if (norm_dist1 < 1e-06 || norm_dist2 < 1e-06) {
        result = 0;
    }
    else {
        // Calculate the intersection of two lines
        double t1 = (v2.y() * (c1.x() - p1.x()) + v2.x() * (p1.y() - c1.y())) / (v1.x() * v2.y() - v2.x() * v1.y());
        double t2 = (v1.y() * (p1.x() - c1.x()) + v1.x() * (c1.y() - p1.y())) / (v2.x() * v1.y() - v1.x() * v2.y());
        if (t1 >= 0 and t1 <= 1 and t2 >= 0 and t2 <= 1) {
            return 1;
        }
    }
    c1 = obj[1];
    c2 = obj[3];
    v2 = c2 - c1;
    norm_dist1 = (v2 - v1).Length();
    norm_dist2 = (v2 + v1).Length();
    if (norm_dist1 < 1e-06 || norm_dist2 < 1e-06) {
        result = 0;
    }
    else {
        // Calculate the intersection of two lines
        double t1 = (v2.y() * (c1.x() - p1.x()) + v2.x() * (p1.y() - c1.y())) / (v1.x() * v2.y() - v2.x() * v1.y());
        double t2 = (v1.y() * (p1.x() - c1.x()) + v1.x() * (c1.y() - p1.y())) / (v2.x() * v1.y() - v1.x() * v2.y());
        if (t1 >= 0 and t1 <= 1 and t2 >= 0 and t2 <= 1) {
            return 1;
        }
    }

    return result;
}
bool checkObj_linev(math::Vec2d p1, math::Vec2d p2){
    double angle = (p2 - p1).Angle();
    double distance = (p2 - p1).Length();
    bool Isfeasible_Line = 1;
    double radius = vehicle_geometrics_.radius;
    double step = radius* 0.1;
    for (double sample=0; sample < distance; sample += step){
        math::Vec2d sample_pt = calc_xy_index(p1.x()+sample*cos(angle), p1.y()+sample*sin(angle));
        if(costmap_.at<uchar>(sample_pt.y(),sample_pt.x())==255){
            return false;
        }
    }
    return true;
}
bool PtInPolygon(math::Vec2d p, vector<math::Vec2d>& ptPolygon)
{
    // wheather p in Polygon
    int nCount = ptPolygon.size() - 1;// number of edges
    int nCross = 0;// number of intersections
    for (int i = 0; i < nCount; i++)
    {
        math::Vec2d p1 = ptPolygon[i];
        math::Vec2d p2 = ptPolygon[(i + 1) % nCount];// line between P1 P2  

        if (p1.y() == p2.y())
            continue;
        if (p.y() < min(p1.y(), p2.y()))
            continue;
        if (p.y() >= max(p1.y(), p2.y()))
            continue;
        // intersection'x   

        double x = (double)(p.y() - p1.y()) * (double)(p2.x() - p1.x()) / (double)(p2.y() - p1.y()) + p1.x();

        // considering intersection on right side  
        if (x > p.x())
        {
            ++nCross;
        }

    }

    // odd when in it 
    if ((nCross % 2) == 1)
    {
        return 1;
    }
    else
    {
        return 0;
    }
}
bool PtInPolygon(double x, double y, vector<math::Vec2d>& ptPolygon) {
    math::Vec2d p(x, y);
    return PtInPolygon(p, ptPolygon);
}
double rand01() {
    return  rand() % (999 + 1) / (float)(999 + 1);
}

// generate random obstacles: obstacles do not overlap with the vehicle's initial/terminal state
vector < vector<math::Vec2d>> GenerateStaticObstacles_unstructured() {
    vector<math::Vec2d> V_initial = CreateVehiclePolygon(vehicle_TPBV_.x0, vehicle_TPBV_.y0, vehicle_TPBV_.theta0);
    vector<math::Vec2d> V_terminal = CreateVehiclePolygon(vehicle_TPBV_.xtf, vehicle_TPBV_.ytf, vehicle_TPBV_.thetatf);
    int count = 0;
    vector<math::Vec2d> obj;
    vector<vector<math::Vec2d>> obstacle_cell;
    double lx = planning_scale_.xmin;
    double ux = planning_scale_.xmax;
    double ly = planning_scale_.ymin;
    double uy = planning_scale_.ymax;
    double W = vehicle_geometrics_.vehicle_width;
    double L = vehicle_geometrics_.vehicle_length;

    int label_obj = 0;
    srand((unsigned)time(NULL));
    while (count < Nobs) {
        //obstacle point
        double x = (ux - lx) * rand01() + lx;
        double y = (uy - ly) * rand01() + ly;
        double theta = 2 * M_PI * rand01() - M_PI;
        double xru = x + L * rand01() * cos(theta);
        double yru = y + L * rand01() * sin(theta);
        double xrd = xru + W * rand01() * sin(theta);
        double yrd = yru - W * rand01() * cos(theta);
        double xld = x + W * rand01() * sin(theta);
        double yld = y - W * rand01() * cos(theta);
        if (xru < lx || xru > ux || xrd < lx || xrd > ux || xld < lx || xld > ux) {
            continue;
        }
        else if (yru < ly || yru > uy || yrd < ly || yrd > uy || yld < ly || yld > uy) {
            continue;
        }

        vector<math::Vec2d> temp_obj;
        math::Vec2d a(x, y);
        math::Vec2d b(xru, yru);
        math::Vec2d c(xrd, yrd);
        math::Vec2d d(xld, yld);
        temp_obj.push_back(a);
        temp_obj.push_back(b);
        temp_obj.push_back(c);
        temp_obj.push_back(d);

        //check the initial / terminal point in the obstacle
        vector<math::Vec2d> temp_obj_margin;
        math::Vec2d tempoint;
        tempoint.set_x(x - margin_obs_); tempoint.set_y(y + margin_obs_);
        temp_obj_margin.push_back(tempoint);
        tempoint.set_x(xru + margin_obs_); tempoint.set_y(yru + margin_obs_);
        temp_obj_margin.push_back(tempoint);
        tempoint.set_x(xrd + margin_obs_); tempoint.set_y(yrd - margin_obs_);
        temp_obj_margin.push_back(tempoint);
        tempoint.set_x(xld - margin_obs_); tempoint.set_y(yld - margin_obs_);
        temp_obj_margin.push_back(tempoint);
        tempoint.set_x(x - margin_obs_); tempoint.set_y(y + margin_obs_);
        temp_obj_margin.push_back(tempoint);
        
        if (PtInPolygon(vehicle_TPBV_.x0, vehicle_TPBV_.y0, temp_obj_margin)
            || PtInPolygon(vehicle_TPBV_.xtf, vehicle_TPBV_.ytf, temp_obj_margin)) {
            continue;
        }


        label_obj = 0;
        // if the generated obstacle overlaps with other obstacles
        if (count > 0) {
            if (checkObj_linev(temp_obj[0], temp_obj[1], obj)
                || checkObj_linev(temp_obj[3], temp_obj[2], obj)
                || checkObj_linev(temp_obj[0], temp_obj[2], obj)
                || checkObj_linev(temp_obj[1], temp_obj[3], obj)) {
                label_obj = 1;
            }
        }
        //if the generated obstacle overlaps with initial and terminal states
        if (count > 0) {
            if (checkObj_linev(temp_obj_margin[0], temp_obj_margin[1], V_initial)
                || checkObj_linev(temp_obj_margin[3], temp_obj_margin[2], V_initial)
                || checkObj_linev(temp_obj_margin[0], temp_obj_margin[2], V_initial)
                || checkObj_linev(temp_obj_margin[1], temp_obj_margin[3], V_initial)
                || checkObj_linev(temp_obj_margin[0], temp_obj_margin[1], V_terminal)
                || checkObj_linev(temp_obj_margin[3], temp_obj_margin[2], V_terminal)
                || checkObj_linev(temp_obj_margin[0], temp_obj_margin[2], V_terminal)
                || checkObj_linev(temp_obj_margin[1], temp_obj_margin[3], V_terminal)) {
                label_obj = 1;
            }
        }


        if (label_obj > 0) {
            continue;
        }

        //if the generated obstacle is effective
        obstacle_cell.push_back(temp_obj);
        count += 1;
        if (count == 1) {
            obj = temp_obj;
        }
        else {
            obj.insert(obj.end(), temp_obj.begin(), temp_obj.end());// put it into obj
        }
    }
    return obstacle_cell;
}