#include <iostream>
using namespace std;
#include <cmath>
#include <vector>
#include <fstream>
#include <string>
//���ı��ļ��е����ݶ���vector�У�������һ��vector��
vector<double> InputData_To_Vector(string filename ="D://x.txt")
{
    //vector<double>* p = new vector<double>;
    //ifstream infile("D://x.txt");
    //double number;
    //while (!infile.eof())
    //{
    //    infile >> number;
    //    p->push_back(number);
    //    cout << "number:" << number << endl;
    //}
    //p->pop_back();  //�˴�Ҫ�����һ�����ֵ���������Ϊ����ѭ�������һ�����ֶ�ȡ������
    //return p;
    vector<double> p;
    ifstream infile(filename);
    double number;
    while (!infile.eof())
    {
        infile >> number;
        p.push_back(number);
        //cout << "number:" << number << endl;
    }
    p.pop_back();  //�˴�Ҫ�����һ�����ֵ���������Ϊ����ѭ�������һ�����ֶ�ȡ������
    return p;
}

inline int Num_Square(int n)
{
    return n * n;
}

int Sum_Of_Num_Square(vector<int>* p)
{
    int Sum2 = 0;
    vector<int>::iterator it;
    for (it = p->begin(); it != p->end(); it++)
    {
        Sum2 += Num_Square(*it);
    }
    return Sum2;
};


int loaddata()
{
    //vector<double> location_x, location_y, location_z;
    ///* Read data from point_right.csv */
    //ifstream fin("D:\\x.csv");                        // ���ļ�������
    //string line;
    //while (getline(fin, line))                           // ���ж�ȡ�����з���\n�����֣������ļ�β��־eof��ֹ��ȡ
    //{
    //    cout << "ԭʼ�ַ���: " << line << endl;           // �������
    //    istringstream sin(line);                         // �������ַ���line���뵽�ַ�����istringstream�� 
    //    vector<string> Waypoints;                        // ����һ���ַ�������
    //    string info;
    //    while (getline(sin, info, ',')) {                // ���ַ�����sin�е��ַ����뵽Waypoints�ַ����У��Զ���Ϊ�ָ���
    //        Waypoints.push_back(info);                   // ���ոն�ȡ���ַ�����ӵ�����Waypoints��
    //    }
    //    // Get x,y,z of points and transform to double
    //    string x_str = Waypoints[3];
    //    string y_str = Waypoints[4];
    //    string z_str = Waypoints[5];

    //    //cout << "x= " << x << "  " << "y= " << y << "  " << "z= " << z << endl;
    //    cout << "Read data done!" << endl;
    //    // Get x,y,z of points and transform to double

    //    double x, y, z;
    //    stringstream sx, sy, sz;
    //    sx << x_str;
    //    sy << y_str;
    //    sz << z_str;
    //    sx >> x;
    //    sy >> y;
    //    sz >> z;
    //    //cout << "x= " << x << "  " << "y= " << y << "  " << "z= " << z << endl;
    //    cout << "Read data done!" << endl;

    //    location_x.push_back(x);
    //    location_y.push_back(y);
    //    location_z.push_back(z);
    //}
    return 0;
};